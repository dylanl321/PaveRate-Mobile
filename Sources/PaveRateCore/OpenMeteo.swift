import Foundation

/// Turns an Open-Meteo forecast body into a `WeatherReading`.
///
/// The request the app sends matches the web client in `src/lib/services/weather.ts`:
/// Fahrenheit, precipitation in millimeters, timezone auto. This parser also reads
/// wind and `soil_temperature_0cm`, which the phone shows and the web client does not.
public enum OpenMeteoParser {
    public struct ParseError: Error, Equatable, Sendable {
        public let message: String
    }

    /// Millimeters to inches. Same factor as the web client (`1 / 25.4`).
    public static let inchesPerMillimeter = 1.0 / 25.4

    public static func parse(
        data: Data,
        latitude: Double,
        longitude: Double,
        now: Date,
        source: WeatherSource = .openMeteo
    ) throws -> WeatherReading {
        let decoder = JSONDecoder()
        let payload: Payload
        do {
            payload = try decoder.decode(Payload.self, from: data)
        } catch {
            throw ParseError(message: "Weather response was not a forecast.")
        }
        guard let current = payload.current, let temperature = current.temperature2m else {
            throw ParseError(message: "Weather response had no current conditions.")
        }
        let offset = payload.utcOffsetSeconds ?? 0
        let zone = TimeZone(secondsFromGMT: offset) ?? TimeZone(secondsFromGMT: 0) ?? .current
        let hours = forecastHours(payload.hourly, zone: zone, now: now)
        let rain = hours.reduce(0.0) { $0 + $1.precipIn }
        let code = current.weatherCode ?? 0
        let precip = current.precipitation ?? 0
        let ground = nearestGround(payload.hourly, zone: zone, now: now)
        return WeatherReading(
            airTempF: FieldFormat.jsRound(temperature),
            windMph: current.windSpeed10m,
            windDirectionDeg: current.windDirection10m,
            windGustMph: current.windGusts10m,
            groundTempF: ground.map { FieldFormat.jsRound($0) },
            conditions: OpenMeteoCodes.label(code),
            isRaining: precip > 0 || OpenMeteoCodes.isRain(code),
            isSnowing: OpenMeteoCodes.isSnow(code),
            rainNext24hIn: rain,
            hours: hours,
            fetchedAt: now,
            latitude: latitude,
            longitude: longitude,
            source: source
        )
    }

    /// Prefer Apple Weather for air, wind, and rain. Keep Open-Meteo's ground temperature.
    public static func merge(kit: WeatherReading, meteo: WeatherReading) -> WeatherReading {
        var combined = kit
        if combined.groundTempF == nil {
            combined.groundTempF = meteo.groundTempF
        }
        if combined.hours.isEmpty {
            combined.hours = meteo.hours
            combined.rainNext24hIn = meteo.rainNext24hIn
        }
        if combined.conditions.isEmpty {
            combined.conditions = meteo.conditions
        }
        combined.source = .merged
        return combined
    }

    private static func forecastHours(_ hourly: Hourly?, zone: TimeZone, now: Date) -> [ForecastHour] {
        guard let hourly, let times = hourly.time else { return [] }
        let end = now.addingTimeInterval(24 * 60 * 60)
        var hours: [ForecastHour] = []
        for index in times.indices {
            guard let time = parseTime(times[index], zone: zone) else { continue }
            if time < now || time > end { continue }
            let precipMm = value(hourly.precipitation, at: index) ?? 0
            hours.append(ForecastHour(
                time: time,
                precipIn: precipMm * inchesPerMillimeter,
                probability: value(hourly.precipitationProbability, at: index) ?? 0,
                airTempF: value(hourly.temperature2m, at: index).map { FieldFormat.jsRound($0) },
                windMph: value(hourly.windSpeed10m, at: index),
                weatherCode: value(hourly.weatherCode, at: index).map { Int($0) }
            ))
        }
        return hours
    }

    private static func nearestGround(_ hourly: Hourly?, zone: TimeZone, now: Date) -> Double? {
        guard let hourly, let times = hourly.time, let soils = hourly.soilTemperature0cm else { return nil }
        var best: (delta: TimeInterval, temp: Double)?
        for index in times.indices {
            guard index < soils.count, let time = parseTime(times[index], zone: zone) else { continue }
            let delta = abs(time.timeIntervalSince(now))
            if best == nil || delta < best?.delta ?? .greatestFiniteMagnitude {
                best = (delta, soils[index])
            }
        }
        return best?.temp
    }

    private static func value(_ values: [Double]?, at index: Int) -> Double? {
        guard let values, index < values.count else { return nil }
        return values[index]
    }

    private static func parseTime(_ text: String, zone: TimeZone) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        let formats = ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

private struct Payload: Decodable {
    var utcOffsetSeconds: Int?
    var current: Current?
    var hourly: Hourly?

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case current
        case hourly
    }
}

private struct Current: Decodable {
    var temperature2m: Double?
    var weatherCode: Int?
    var precipitation: Double?
    var windSpeed10m: Double?
    var windDirection10m: Double?
    var windGusts10m: Double?

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
        case precipitation
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case windGusts10m = "wind_gusts_10m"
    }
}

private struct Hourly: Decodable {
    var time: [String]?
    var precipitation: [Double]?
    var precipitationProbability: [Double]?
    var weatherCode: [Double]?
    var temperature2m: [Double]?
    var soilTemperature0cm: [Double]?
    var windSpeed10m: [Double]?

    enum CodingKeys: String, CodingKey {
        case time
        case precipitation
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weather_code"
        case temperature2m = "temperature_2m"
        case soilTemperature0cm = "soil_temperature_0cm"
        case windSpeed10m = "wind_speed_10m"
    }
}
