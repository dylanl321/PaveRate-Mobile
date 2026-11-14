import CoreLocation
import Foundation
import WeatherKit
import PaveRateCore

/// Location for weather and for walking the run. When-in-use only. Tracking stops when the view stops it.
@MainActor
@Observable
final class FieldLocation {
    var coordinate: GeoPoint?
    var horizontalAccuracyM: Double = -1
    var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let bridge = LocationBridge()

    init() {
        manager.delegate = bridge
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .automotiveNavigation
        bridge.owner = self
        authorization = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined, .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func requestAndStart() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    fileprivate func apply(location: CLLocation) {
        coordinate = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        horizontalAccuracyM = location.horizontalAccuracy
    }

    fileprivate func apply(status: CLAuthorizationStatus) {
        authorization = status
    }
}

private final class LocationBridge: NSObject, CLLocationManagerDelegate {
    weak var owner: FieldLocation?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.owner?.apply(status: status)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.owner?.apply(location: location)
        }
    }
}

enum OpenMeteoClient {
    private static let forecastURL = URL(string: "https://api.open-meteo.com/v1/forecast")

    static func fetch(latitude: Double, longitude: Double, now: Date = Date()) async throws -> WeatherReading {
        guard var components = URLComponents(url: forecastURL!, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,precipitation,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            URLQueryItem(name: "hourly", value: "precipitation,precipitation_probability,weather_code,temperature_2m,soil_temperature_0cm,wind_speed_10m"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "precipitation_unit", value: "mm"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try OpenMeteoParser.parse(data: data, latitude: latitude, longitude: longitude, now: now)
    }
}

enum WeatherKitSource {
    static func fetch(latitude: Double, longitude: Double, now: Date = Date()) async throws -> WeatherReading {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let service = WeatherKit.WeatherService.shared
        let (current, hourly) = try await service.weather(for: location, including: .current, .hourly)
        let end = now.addingTimeInterval(24 * 60 * 60)
        let hours: [ForecastHour] = hourly.forecast.compactMap { hour in
            guard hour.date >= now, hour.date <= end else { return nil }
            return ForecastHour(
                time: hour.date,
                precipIn: hour.precipitationAmount.converted(to: .inches).value,
                probability: hour.precipitationChance * 100,
                airTempF: FieldFormat.jsRound(hour.temperature.converted(to: .fahrenheit).value),
                windMph: hour.wind.speed.converted(to: .milesPerHour).value,
                weatherCode: nil
            )
        }
        let rain = hours.reduce(0.0) { $0 + $1.precipIn }
        let wet = WeatherKitWords.isWet(current.condition) || current.precipitationIntensity.converted(to: .metersPerSecond).value > 0
        return WeatherReading(
            airTempF: FieldFormat.jsRound(current.temperature.converted(to: .fahrenheit).value),
            windMph: current.wind.speed.converted(to: .milesPerHour).value,
            windDirectionDeg: current.wind.direction.converted(to: .degrees).value,
            windGustMph: current.wind.gust?.converted(to: .milesPerHour).value,
            groundTempF: nil,
            conditions: WeatherKitWords.label(current.condition),
            isRaining: wet && !WeatherKitWords.isSnow(current.condition),
            isSnowing: WeatherKitWords.isSnow(current.condition),
            rainNext24hIn: rain,
            hours: hours,
            fetchedAt: now,
            latitude: latitude,
            longitude: longitude,
            source: .weatherKit
        )
    }
}

enum FieldWeatherFetch {
    /// WeatherKit first. Open-Meteo fills ground temperature and covers a missing entitlement.
    static func load(latitude: Double, longitude: Double) async -> WeatherReading? {
        let kitTask = Task { try? await WeatherKitSource.fetch(latitude: latitude, longitude: longitude) }
        let meteoTask = Task { try? await OpenMeteoClient.fetch(latitude: latitude, longitude: longitude) }
        let kit = await kitTask.value
        let meteo = await meteoTask.value
        switch (kit, meteo) {
        case let (kit?, meteo?):
            return OpenMeteoParser.merge(kit: kit, meteo: meteo)
        case let (kit?, nil):
            return kit
        case let (nil, meteo?):
            return meteo
        case (nil, nil):
            return nil
        }
    }
}

/// WeatherKit's condition list grows. Anything we do not recognize is treated as dry.
private enum WeatherKitWords {
    static func isWet(_ condition: WeatherCondition) -> Bool {
        switch condition {
        case .drizzle, .heavyRain, .rain, .sunShowers, .freezingDrizzle, .freezingRain,
             .thunderstorms, .strongStorms, .isolatedThunderstorms, .scatteredThunderstorms,
             .sleet, .wintryMix, .hail, .snow, .flurries, .heavySnow, .blowingSnow, .blizzard, .sunFlurries:
            return true
        default:
            return false
        }
    }

    static func isSnow(_ condition: WeatherCondition) -> Bool {
        switch condition {
        case .snow, .flurries, .heavySnow, .blowingSnow, .blizzard, .sunFlurries, .sleet, .wintryMix:
            return true
        default:
            return false
        }
    }

    static func label(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:
            return "Clear"
        case .partlyCloudy, .mostlyCloudy:
            return "Partly cloudy"
        case .cloudy:
            return "Overcast"
        case .foggy, .haze, .smoky:
            return "Fog"
        case .drizzle, .rain, .sunShowers:
            return "Rain"
        case .heavyRain, .thunderstorms, .strongStorms, .isolatedThunderstorms, .scatteredThunderstorms:
            return "Heavy rain"
        case .snow, .flurries, .sunFlurries, .blowingSnow, .heavySnow, .blizzard:
            return "Snow"
        case .sleet, .wintryMix, .freezingRain, .freezingDrizzle, .hail:
            return "Wintry mix"
        default:
            return "Forecast"
        }
    }
}
