import Foundation

public enum LengthDisplay: String, Codable, Equatable, Sendable, CaseIterable {
    case feet
    case stations

    public var title: String {
        switch self {
        case .feet: return "Feet"
        case .stations: return "Stations"
        }
    }
}

/// Crew preferences. The paving math stays in US customary units either way.
public struct FieldSettings: Codable, Equatable, Sendable {
    public var windNoteMph: Double
    public var strongWindMph: Double
    /// Call the plant when tons still to place are at or under this, or when placed tons pass the order.
    public var plantCallTons: Double
    public var defaultWidthFt: Double
    public var defaultThicknessIn: Double
    public var defaultCourseTypeId: String
    public var defaultMachineId: String
    public var preferGlare: Bool
    public var foremanName: String
    public var crewName: String
    public var lengthDisplay: LengthDisplay

    public init(
        windNoteMph: Double = WeatherPolicy.windNoteMph,
        strongWindMph: Double = WeatherPolicy.windStrongMph,
        plantCallTons: Double = PaveRateConfig.defaultTruckLoadTons,
        defaultWidthFt: Double = PaveRateConfig.defaultRoadWidthFt,
        defaultThicknessIn: Double = PaveRateConfig.defaultThicknessIn,
        defaultCourseTypeId: String = PaveRateConfig.defaultCourseTypeId,
        defaultMachineId: String = PaveRateConfig.defaultMachineId,
        preferGlare: Bool = false,
        foremanName: String = "",
        crewName: String = "",
        lengthDisplay: LengthDisplay = .feet
    ) {
        self.windNoteMph = windNoteMph
        self.strongWindMph = strongWindMph
        self.plantCallTons = plantCallTons
        self.defaultWidthFt = defaultWidthFt
        self.defaultThicknessIn = defaultThicknessIn
        self.defaultCourseTypeId = defaultCourseTypeId
        self.defaultMachineId = defaultMachineId
        self.preferGlare = preferGlare
        self.foremanName = foremanName
        self.crewName = crewName
        self.lengthDisplay = lengthDisplay
    }

    public var peopleLine: String? {
        var parts: [String] = []
        let foreman = foremanName.trimmingCharacters(in: .whitespacesAndNewlines)
        let crew = crewName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !foreman.isEmpty { parts.append("Foreman \(foreman)") }
        if !crew.isEmpty { parts.append("Crew \(crew)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The big length on the run. The other unit stays in the caption. Spec math is unchanged.
    public func lengthHeadline(feet: Double) -> String {
        switch lengthDisplay {
        case .feet:
            return "\(FieldFormat.groupedRound(feet)) ft"
        case .stations:
            return GeoMeasure.stationLabel(feet: feet)
        }
    }
}

public struct PlantCall: Equatable, Sendable {
    public var shouldCall: Bool
    public var message: String

    public init(shouldCall: Bool, message: String) {
        self.shouldCall = shouldCall
        self.message = message
    }
}

public enum PlantCallCheck {
    /// Warn when the placed tons pass the order, or when what is left is at or under the threshold.
    public static func evaluate(orderedTons: Double?, placedTons: Double, thresholdTons: Double) -> PlantCall {
        guard let orderedTons else {
            return PlantCall(shouldCall: false, message: "Enter tons ordered to watch the plant.")
        }
        let remaining = orderedTons - placedTons
        if remaining < 0 {
            let over = FieldFormat.fixed(-remaining, digits: 1)
            return PlantCall(shouldCall: true, message: "\(over) tons over the order. Call the plant.")
        }
        if remaining <= thresholdTons {
            let left = FieldFormat.fixed(remaining, digits: 1)
            return PlantCall(shouldCall: true, message: "\(left) tons left. Call the plant before the paver waits.")
        }
        return PlantCall(shouldCall: false, message: "\(FieldFormat.fixed(remaining, digits: 1)) tons still on the order.")
    }
}
