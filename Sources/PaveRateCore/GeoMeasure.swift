import Foundation

/// A WGS84 point. Latitude and longitude are degrees.
public struct GeoPoint: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Length and area for a paving run.
///
/// Haversine constants match the web app's `CONST.EARTH_RADIUS_M` (6,371,000)
/// and `CONST.FT_PER_M` (3.28084). Stationing matches `CONST.FT_PER_STATION` (100).
/// A mile matches `CONST.FT_PER_MILE` (5,280). Turf's polyline length on the web
/// is the same haversine, converted with that feet-per-meter factor.
public enum GeoMeasure {
    public static let earthRadiusM = 6_371_000.0
    public static let feetPerMeter = 3.28084
    public static let feetPerStation = 100.0
    public static let feetPerMile = 5_280.0
    /// Ignore a GPS fix worse than this. A 30 m fix is a lane and a half.
    public static let maxTrackAccuracyM = 30.0
    /// Ignore a fix closer than this so a stopped truck does not grow the line.
    public static let minTrackSpacingFt = 10.0
    public static let maxTrackPoints = 5_000
    /// Paved length this far past the plan is wander or a missed end, not a rounding error.
    public static let overrunFraction = 1.05

    public static func haversineMeters(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let phi1 = a.latitude * .pi / 180
        let phi2 = b.latitude * .pi / 180
        let dPhi = (b.latitude - a.latitude) * .pi / 180
        let dLambda = (b.longitude - a.longitude) * .pi / 180
        let sinPhi = sin(dPhi / 2)
        let sinLambda = sin(dLambda / 2)
        let h = sinPhi * sinPhi + cos(phi1) * cos(phi2) * sinLambda * sinLambda
        let clamped = min(1, max(0, h))
        return earthRadiusM * 2 * atan2(sqrt(clamped), sqrt(1 - clamped))
    }

    public static func haversineFeet(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        haversineMeters(a, b) * feetPerMeter
    }

    public static func polylineFeet(_ points: [GeoPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for index in 0..<(points.count - 1) {
            total += haversineFeet(points[index], points[index + 1])
        }
        return total
    }

    /// Area of a run at the job width. Square yards, same as `squareYards`.
    public static func areaSquareYards(lengthFt: Double, widthFt: Double) -> Double {
        squareYards(max(0, lengthFt), max(0, widthFt))
    }

    public static func miles(feet: Double) -> Double {
        feet / feetPerMile
    }

    /// Survey station from feet. 1,250 ft is `12+50`.
    public static func stationLabel(feet: Double) -> String {
        let total = Int(FieldFormat.jsRound(feet))
        let sign = total < 0 ? "-" : ""
        let absolute = abs(total)
        let major = absolute / 100
        let minor = absolute % 100
        return "\(sign)\(major)+\(String(format: "%02d", locale: Locale(identifier: "en_US_POSIX"), minor))"
    }

    /// Compass point for a meteorological wind direction (degrees the wind is coming from).
    public static func compassLabel(degrees: Double) -> String {
        let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let positive = wrapped < 0 ? wrapped + 360 : wrapped
        let index = Int(FieldFormat.jsRound(positive / 45)) % 8
        return names[index]
    }

    public static func pointAlong(points: [GeoPoint], feet: Double) -> GeoPoint? {
        let prefix = prefix(points: points, feet: feet)
        return prefix.last
    }

    /// Points from the start of the line through `feet`, with the end interpolated.
    public static func prefix(points: [GeoPoint], feet: Double) -> [GeoPoint] {
        guard let first = points.first else { return [] }
        if points.count == 1 || feet <= 0 { return [first] }
        var result = [first]
        var remaining = feet
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let segment = haversineFeet(start, end)
            if segment <= 0 { continue }
            if remaining < segment {
                result.append(interpolate(start, end, t: remaining / segment))
                return result
            }
            remaining -= segment
            result.append(end)
            if remaining == 0 { return result }
        }
        return result
    }

    /// Add a GPS fix to a paved track. Rejects poor accuracy, duplicates, and a full track.
    public static func appendTrackPoint(
        _ points: [GeoPoint],
        next: GeoPoint,
        accuracyMeters: Double,
        maxAccuracyMeters: Double = maxTrackAccuracyM,
        minSpacingFeet: Double = minTrackSpacingFt,
        maxPoints: Int = maxTrackPoints
    ) -> [GeoPoint] {
        guard accuracyMeters >= 0, accuracyMeters <= maxAccuracyMeters else { return points }
        guard abs(next.latitude) <= 90, abs(next.longitude) <= 180 else { return points }
        guard points.count < maxPoints else { return points }
        guard let last = points.last else { return [next] }
        if haversineFeet(last, next) < minSpacingFeet { return points }
        return points + [next]
    }

    public static func measure(planned: [GeoPoint], paved: [GeoPoint], widthFt: Double) -> RunMeasure {
        let plannedFeet = polylineFeet(planned)
        let pavedFeet = polylineFeet(paved)
        let remaining = plannedFeet > 0 ? max(0, plannedFeet - pavedFeet) : 0
        let fraction = plannedFeet > 0 ? pavedFeet / plannedFeet : 0
        let lengthForCalcs = plannedFeet > 0 ? plannedFeet : pavedFeet
        return RunMeasure(
            plannedFeet: plannedFeet,
            pavedFeet: pavedFeet,
            remainingFeet: remaining,
            plannedAreaSqYd: areaSquareYards(lengthFt: plannedFeet, widthFt: widthFt),
            pavedAreaSqYd: areaSquareYards(lengthFt: pavedFeet, widthFt: widthFt),
            fraction: fraction,
            lengthForCalcs: lengthForCalcs,
            stationPlanned: stationLabel(feet: plannedFeet),
            stationPaved: stationLabel(feet: pavedFeet),
            overrun: plannedFeet > 0 && pavedFeet > plannedFeet * overrunFraction
        )
    }

    private static func interpolate(_ a: GeoPoint, _ b: GeoPoint, t: Double) -> GeoPoint {
        let clamped = min(1, max(0, t))
        return GeoPoint(
            latitude: a.latitude + (b.latitude - a.latitude) * clamped,
            longitude: a.longitude + (b.longitude - a.longitude) * clamped
        )
    }
}

public struct RunMeasure: Equatable, Sendable {
    public var plannedFeet: Double
    public var pavedFeet: Double
    public var remainingFeet: Double
    public var plannedAreaSqYd: Double
    public var pavedAreaSqYd: Double
    /// Paved length divided by planned length. Can exceed 1 when the track overruns the plan.
    public var fraction: Double
    /// Plan length when a plan exists, otherwise the paved track. This is what the calculators take.
    public var lengthForCalcs: Double
    public var stationPlanned: String
    public var stationPaved: String
    public var overrun: Bool

    public init(
        plannedFeet: Double,
        pavedFeet: Double,
        remainingFeet: Double,
        plannedAreaSqYd: Double,
        pavedAreaSqYd: Double,
        fraction: Double,
        lengthForCalcs: Double,
        stationPlanned: String,
        stationPaved: String,
        overrun: Bool
    ) {
        self.plannedFeet = plannedFeet
        self.pavedFeet = pavedFeet
        self.remainingFeet = remainingFeet
        self.plannedAreaSqYd = plannedAreaSqYd
        self.pavedAreaSqYd = pavedAreaSqYd
        self.fraction = fraction
        self.lengthForCalcs = lengthForCalcs
        self.stationPlanned = stationPlanned
        self.stationPaved = stationPaved
        self.overrun = overrun
    }
}
