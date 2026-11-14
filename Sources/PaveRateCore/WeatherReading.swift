import Foundation

public enum WeatherSource: String, Codable, Sendable {
    case weatherKit
    case openMeteo
    case merged
}

public struct ForecastHour: Codable, Equatable, Sendable {
    public var time: Date
    public var precipIn: Double
    public var probability: Double
    public var airTempF: Double?
    public var windMph: Double?
    public var weatherCode: Int?

    public init(
        time: Date,
        precipIn: Double,
        probability: Double,
        airTempF: Double? = nil,
        windMph: Double? = nil,
        weatherCode: Int? = nil
    ) {
        self.time = time
        self.precipIn = precipIn
        self.probability = probability
        self.airTempF = airTempF
        self.windMph = windMph
        self.weatherCode = weatherCode
    }
}

/// One weather pull, normalized so WeatherKit and Open-Meteo share a shape.
public struct WeatherReading: Codable, Equatable, Sendable {
    public var airTempF: Double
    public var windMph: Double?
    public var windDirectionDeg: Double?
    public var windGustMph: Double?
    /// Open-Meteo soil temperature at 0 cm. Not an infrared reading of the mat.
    public var groundTempF: Double?
    public var conditions: String
    public var isRaining: Bool
    public var isSnowing: Bool
    public var rainNext24hIn: Double
    public var hours: [ForecastHour]
    public var fetchedAt: Date
    public var latitude: Double
    public var longitude: Double
    public var source: WeatherSource

    public init(
        airTempF: Double,
        windMph: Double? = nil,
        windDirectionDeg: Double? = nil,
        windGustMph: Double? = nil,
        groundTempF: Double? = nil,
        conditions: String,
        isRaining: Bool,
        isSnowing: Bool = false,
        rainNext24hIn: Double,
        hours: [ForecastHour],
        fetchedAt: Date,
        latitude: Double,
        longitude: Double,
        source: WeatherSource
    ) {
        self.airTempF = airTempF
        self.windMph = windMph
        self.windDirectionDeg = windDirectionDeg
        self.windGustMph = windGustMph
        self.groundTempF = groundTempF
        self.conditions = conditions
        self.isRaining = isRaining
        self.isSnowing = isSnowing
        self.rainNext24hIn = rainNext24hIn
        self.hours = hours
        self.fetchedAt = fetchedAt
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
    }

    public var suggestsWetSurface: Bool { isRaining || isSnowing }
}

public enum WeatherFreshness: Equatable, Sendable {
    case fresh
    case aging
    case stale
}

/// Whether a saved reading may fill the job without another tap.
public struct WeatherApplyPolicy: Equatable, Sendable {
    public var replaceAir: Bool
    public var replaceRain: Bool
    public var setSurfaceWet: Bool

    public init(replaceAir: Bool, replaceRain: Bool, setSurfaceWet: Bool) {
        self.replaceAir = replaceAir
        self.replaceRain = replaceRain
        self.setSurfaceWet = setSurfaceWet
    }
}

public enum WeatherPolicy {
    /// Same refresh window as the web app's `weather.refreshMinutes`.
    public static let freshSeconds: TimeInterval = 30 * 60
    /// Past this, show the reading and do not apply it on your own.
    public static let staleSeconds: TimeInterval = 6 * 60 * 60
    /// A reading taken farther away than this is a different place, not this mat.
    public static let sameJobRadiusFt = 15 * GeoMeasure.feetPerMile
    /// Field estimate. Not a GDOT clause. Amber note only.
    public static let windNoteMph = 15.0
    public static let windStrongMph = 25.0
    public static let frozenGroundF = 32.0

    public static func freshness(fetchedAt: Date, now: Date) -> WeatherFreshness {
        let age = now.timeIntervalSince(fetchedAt)
        if age < freshSeconds { return .fresh }
        if age < staleSeconds { return .aging }
        return .stale
    }

    public static func ageText(fetchedAt: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(fetchedAt)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        return "\(hours) h ago"
    }

    public static func driftFeet(reading: WeatherReading, current: GeoPoint) -> Double {
        GeoMeasure.haversineFeet(
            GeoPoint(latitude: reading.latitude, longitude: reading.longitude),
            current
        )
    }

    /// No current fix means we cannot call it drifted. A bridge is not a different job.
    public static func hasDrifted(reading: WeatherReading, current: GeoPoint?) -> Bool {
        guard let current else { return false }
        return driftFeet(reading: reading, current: current) > sameJobRadiusFt
    }

    public static func applyPolicy(
        freshness: WeatherFreshness,
        followsGPS: Bool,
        airLocked: Bool,
        rainLocked: Bool,
        drifted: Bool
    ) -> WeatherApplyPolicy {
        let trusted = followsGPS && freshness != .stale && !drifted
        return WeatherApplyPolicy(
            replaceAir: trusted && !airLocked,
            replaceRain: trusted && !rainLocked,
            setSurfaceWet: trusted
        )
    }

    /// Fill temperature and rain. Set the surface wet when it is raining or snowing.
    /// Never clears a wet flag. Puddles outlast the radar pixel.
    public static func applying(
        _ reading: WeatherReading,
        to job: JobSetup,
        policy: WeatherApplyPolicy
    ) -> JobSetup {
        var job = job
        if policy.replaceAir {
            job.airTempF = reading.airTempF
        }
        if policy.replaceRain {
            job.rainNext24hIn = reading.rainNext24hIn
        }
        if policy.setSurfaceWet && reading.suggestsWetSurface {
            job.surfaceWet = true
        }
        return job
    }
}

public struct WeatherDecision: Equatable, Sendable {
    public var placement: PlacementCheck?
    public var rain: RainCheck?
    public var tack: TackTempCheck?
    public var openGraded: CourseAirTempCheck?
    public var windNote: String?
    public var groundNote: String?
    public var headline: String
    public var status: PlacementStatus
    public var suggestSurfaceWet: Bool

    public init(
        placement: PlacementCheck?,
        rain: RainCheck?,
        tack: TackTempCheck?,
        openGraded: CourseAirTempCheck?,
        windNote: String?,
        groundNote: String?,
        headline: String,
        status: PlacementStatus,
        suggestSurfaceWet: Bool
    ) {
        self.placement = placement
        self.rain = rain
        self.tack = tack
        self.openGraded = openGraded
        self.windNote = windNote
        self.groundNote = groundNote
        self.headline = headline
        self.status = status
        self.suggestSurfaceWet = suggestSurfaceWet
    }
}

public enum WeatherDecisions {
    /// Map a reading onto the GDOT checks the calculators already use.
    public static func decide(
        reading: WeatherReading,
        job: JobSetup,
        windNoteMph: Double = WeatherPolicy.windNoteMph,
        strongWindMph: Double = WeatherPolicy.windStrongMph
    ) -> WeatherDecision {
        let placement = placementCheck(airTempF: reading.airTempF, thicknessIn: job.thicknessIn)
        let rain = rainCheck(totalRainIn: reading.rainNext24hIn)
        let tack = tackTempCheck(airTempF: reading.airTempF)
        let openGraded = openGradedAirTempCheck(airTempF: reading.airTempF, courseId: job.courseTypeId)
        let windNote = windNote(mph: reading.windMph, noteAt: windNoteMph, strongAt: strongWindMph)
        let groundNote = groundNote(tempF: reading.groundTempF)
        let ranked = rank(
            rain: rain,
            placement: placement,
            openGraded: openGraded,
            tack: tack,
            windNote: windNote,
            groundNote: groundNote
        )
        return WeatherDecision(
            placement: placement,
            rain: rain,
            tack: tack,
            openGraded: openGraded,
            windNote: windNote,
            groundNote: groundNote,
            headline: ranked.headline,
            status: ranked.status,
            suggestSurfaceWet: reading.suggestsWetSurface
        )
    }

    /// Hours the web app would list: any rain, a 40% chance, or a rain code.
    public static func rainThreats(in hours: [ForecastHour]) -> [ForecastHour] {
        hours.filter { hour in
            hour.precipIn > 0 || hour.probability >= 40 || OpenMeteoCodes.isRain(hour.weatherCode)
        }
    }

    public static func sourceLabel(_ source: WeatherSource) -> String {
        switch source {
        case .weatherKit:
            return "Apple Weather"
        case .openMeteo:
            return "Open-Meteo"
        case .merged:
            return "Apple Weather"
        }
    }

    private static func windNote(mph: Double?, noteAt: Double, strongAt: Double) -> String? {
        guard let mph, mph >= noteAt else { return nil }
        let shown = FieldFormat.jsNumber(FieldFormat.jsRound(mph))
        if mph >= max(strongAt, noteAt) {
            return "Field note, not a GDOT cutoff: wind \(shown) mph. Most crews hold tack in this. The mat cools faster too."
        }
        return "Field note, not a GDOT cutoff: wind \(shown) mph. Tack drifts and the mat cools faster."
    }

    private static func groundNote(tempF: Double?) -> String? {
        guard let tempF, tempF < WeatherPolicy.frozenGroundF else { return nil }
        return "Forecast ground temperature is \(FieldFormat.jsNumber(tempF))°F. Table 4 says the base must not be frozen. This is a soil forecast, not an infrared reading of the mat."
    }

    private static func rank(
        rain: RainCheck?,
        placement: PlacementCheck?,
        openGraded: CourseAirTempCheck?,
        tack: TackTempCheck?,
        windNote: String?,
        groundNote: String?
    ) -> (headline: String, status: PlacementStatus) {
        if rain?.status == .fail {
            return ("Hold — rain in the next 24 h", .fail)
        }
        if placement?.status == .fail {
            return ("Too cold to pave", .fail)
        }
        if openGraded?.status == .fail {
            return ("Too cold for \(openGraded?.label ?? "OGFC/PEM")", .fail)
        }
        if tack?.status == .fail {
            return ("Too cold to tack", .fail)
        }
        let warning = rain?.status == .warn
            || placement?.status == .warn
            || openGraded?.status == .warn
            || tack?.status == .warn
            || windNote != nil
            || groundNote != nil
        if warning {
            return ("Borderline — watch it", .warn)
        }
        return ("OK to pave", .pass)
    }
}

enum OpenMeteoCodes {
    static let rain: Set<Int> = [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99]
    static let snow: Set<Int> = [71, 73, 75, 77, 85, 86]

    static func isRain(_ code: Int?) -> Bool {
        guard let code else { return false }
        return rain.contains(code)
    }

    static func isSnow(_ code: Int?) -> Bool {
        guard let code else { return false }
        return snow.contains(code)
    }

    static func label(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51: return "Light drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy drizzle"
        case 61: return "Light rain"
        case 63: return "Rain"
        case 65: return "Heavy rain"
        case 71: return "Light snow"
        case 73: return "Snow"
        case 75: return "Heavy snow"
        case 80, 81: return "Rain showers"
        case 82: return "Heavy showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }
}
