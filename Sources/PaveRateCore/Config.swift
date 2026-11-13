import Foundation

public enum VerificationStatus: String, Sendable, Equatable {
    case verified = "VERIFIED"
    case fieldEstimate = "FIELD_ESTIMATE"
    case unverified = "UNVERIFIED"
    case conflict = "CONFLICT"
    case na = "NA"
}

public struct ConstantEntry: Sendable, Equatable {
    public let value: Double
    public let unit: String
    public let status: VerificationStatus
    public let note: String?

    public init(value: Double, unit: String, status: VerificationStatus, note: String? = nil) {
        self.value = value
        self.unit = unit
        self.status = status
        self.note = note
    }
}

public struct MachineEntry: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let retainTons: Double

    public init(id: String, label: String, retainTons: Double) {
        self.id = id
        self.label = label
        self.retainTons = retainTons
    }
}

public struct TackRate: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let min: Double
    public let max: Double
    public let unit: String
    public let status: VerificationStatus

    public init(id: String, label: String, min: Double, max: Double, unit: String, status: VerificationStatus) {
        self.id = id
        self.label = label
        self.min = min
        self.max = max
        self.unit = unit
        self.status = status
    }

    public var mid: Double { (min + max) / 2 }
}

public struct TempBand: Sendable, Equatable, Identifiable {
    public let id: String
    public let maxThicknessIn: Double
    public let minAirTempF: Double
    public let status: VerificationStatus
    public let note: String?

    public init(
        id: String,
        maxThicknessIn: Double,
        minAirTempF: Double,
        status: VerificationStatus,
        note: String? = nil
    ) {
        self.id = id
        self.maxThicknessIn = maxThicknessIn
        self.minAirTempF = minAirTempF
        self.status = status
        self.note = note
    }
}

public struct SpreadTolerance: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let toleranceLbsSy: Double
    public let note: String
    public let status: VerificationStatus
    public let specRef: String

    public init(
        id: String,
        label: String,
        toleranceLbsSy: Double,
        note: String,
        status: VerificationStatus,
        specRef: String
    ) {
        self.id = id
        self.label = label
        self.toleranceLbsSy = toleranceLbsSy
        self.note = note
        self.status = status
        self.specRef = specRef
    }
}

public struct Table12Row: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let thicknessTolerance: String
    public let spreadTolerance: String
    public let note: String?

    public init(id: String, label: String, thicknessTolerance: String, spreadTolerance: String, note: String? = nil) {
        self.id = id
        self.label = label
        self.thicknessTolerance = thicknessTolerance
        self.spreadTolerance = spreadTolerance
        self.note = note
    }
}

public struct WeatherLimits: Sendable, Equatable {
    public let rainWarnIn: Double
    public let rainBlockIn: Double
    public let tempWarnMarginF: Double
    public let ogfcMinAirTempF: Double
    public let tackMinAirTempF: Double
    public let wetSurfaceBlocked: Bool
}

/// Numeric source of truth transcribed from `Config/paverate-asphalt.yaml`.
/// Lookup helpers match `src/lib/config/index.ts`.
public enum PaveRateConfig {
    public static let constants: [String: ConstantEntry] = [
        "SF_PER_SY": ConstantEntry(value: 9, unit: "sq ft / sq yd", status: .na),
        "LB_PER_TON": ConstantEntry(value: 2000, unit: "lb / ton", status: .na),
        "TRUCK_LOAD": ConstantEntry(
            value: 18.5,
            unit: "tons",
            status: .fieldEstimate,
            note: "Fleet rule-of-thumb; user-editable per job"
        ),
        "SHUTTLE_RETAIN": ConstantEntry(value: 24, unit: "tons", status: .fieldEstimate),
        "PAVER_RETAIN": ConstantEntry(value: 14, unit: "tons", status: .fieldEstimate),
        "THICK_MULT": ConstantEntry(
            value: 110,
            unit: "lbs/SY per in",
            status: .fieldEstimate,
            note: "HMA unit-weight rule-of-thumb"
        ),
        "STICK_FACTOR": ConstantEntry(
            value: 1.25,
            unit: "x",
            status: .fieldEstimate,
            note: "Loose-vs-compacted estimate"
        )
    ]

    public static let machines: [MachineEntry] = [
        MachineEntry(id: "paver", label: "Paver", retainTons: 14),
        MachineEntry(id: "shuttle", label: "Shuttle Buggy", retainTons: 24),
        MachineEntry(id: "mtv", label: "MTV", retainTons: 24),
        MachineEntry(id: "none", label: "None", retainTons: 0)
    ]

    public static let tackField: [TackRate] = [
        TackRate(id: "TACK.FIELD_LEVELING", label: "Leveling", min: 0.040, max: 0.060, unit: "gal/SY", status: .fieldEstimate),
        TackRate(id: "TACK.FIELD_TOPPING", label: "Topping", min: 0.040, max: 0.060, unit: "gal/SY", status: .fieldEstimate),
        TackRate(id: "TACK.FIELD_OGI", label: "OGI (Open-Graded Interlayer)", min: 0.060, max: 0.080, unit: "gal/SY", status: .fieldEstimate),
        TackRate(id: "TACK.FIELD_ROCKCHIP", label: "Rock Chip", min: 0.085, max: 0.085, unit: "gal/SY", status: .fieldEstimate)
    ]

    public static let tackSpec: [TackRate] = [
        TackRate(id: "TACK.NEW_AC", label: "New AC to New AC / thin-lift leveling", min: 0.05, max: 0.08, unit: "gal/yd2", status: .unverified),
        TackRate(id: "TACK.AGED_LE25RAP", label: "New AC (<=25% RAP) to aged/milled", min: 0.06, max: 0.10, unit: "gal/yd2", status: .unverified),
        TackRate(id: "TACK.AGED_GT25RAP", label: "New AC (>25% RAP) to aged/milled", min: 0.08, max: 0.12, unit: "gal/yd2", status: .unverified)
    ]

    public static let temperature: [TempBand] = [
        TempBand(id: "TEMP.LE_1IN", maxThicknessIn: 1.0, minAirTempF: 55, status: .unverified),
        TempBand(id: "TEMP.1_2IN", maxThicknessIn: 2.0, minAirTempF: 45, status: .unverified),
        TempBand(id: "TEMP.2_3IN", maxThicknessIn: 3.0, minAirTempF: 40, status: .unverified),
        TempBand(id: "TEMP.3_4IN", maxThicknessIn: 4.0, minAirTempF: 35, status: .unverified),
        TempBand(
            id: "TEMP.4_8IN",
            maxThicknessIn: 8.0,
            minAirTempF: 32,
            status: .unverified,
            note: "32F and rising; base must not be frozen"
        )
    ]

    public static let spreadTolerance: [SpreadTolerance] = [
        SpreadTolerance(
            id: "TOLERANCE.BASE",
            label: "Base course",
            toleranceLbsSy: 55,
            note: "Asphaltic concrete base course (also any combination of base + surface)",
            status: .verified,
            specRef: "SS-400.3.03"
        ),
        SpreadTolerance(
            id: "TOLERANCE.INTERMEDIATE_WEARING",
            label: "Intermediate / wearing course",
            toleranceLbsSy: 27.5,
            note: "Intermediate and/or wearing course",
            status: .verified,
            specRef: "SS-400.3.03"
        ),
        SpreadTolerance(
            id: "TOLERANCE.OGFC",
            label: "OGFC (9.5 / 12.5 mm)",
            toleranceLbsSy: 7,
            note: "Control spread rate per lot within 7 lbs/yd2 of the designated rate",
            status: .verified,
            specRef: "SS-400.3.03"
        ),
        SpreadTolerance(
            id: "TOLERANCE.PEM",
            label: "12.5 mm PEM",
            toleranceLbsSy: 10,
            note: "Control spread rate per lot within 10 lbs/yd2 of the designated rate",
            status: .verified,
            specRef: "SS-400.3.03"
        )
    ]

    public static let table12: [Table12Row] = [
        Table12Row(id: "TOLERANCE.BASE", label: "Asphaltic concrete base course", thicknessTolerance: "±0.5 in. (±13 mm)", spreadTolerance: "±55 lbs/yd² (30 kg/m²)"),
        Table12Row(id: "TOLERANCE.INTERMEDIATE_WEARING", label: "Intermediate and/or wearing course", thicknessTolerance: "±0.25 in. (±6 mm)", spreadTolerance: "±27.5 lbs/yd² (15 kg/m²)"),
        Table12Row(id: "TOLERANCE.BASE_PLUS_SURFACE", label: "Overall of any combination of 1 and 2", thicknessTolerance: "±0.5 in. (±13 mm)", spreadTolerance: "±55 lbs/yd² (30 kg/m²)"),
        Table12Row(id: "TOLERANCE.OGFC", label: "9.5 mm OGFC and 12.5 mm OGFC", thicknessTolerance: "—", spreadTolerance: "±7 lbs/yd² (4 kg/m²)", note: "Control spread rate per lot"),
        Table12Row(id: "TOLERANCE.PEM", label: "12.5 mm PEM", thicknessTolerance: "—", spreadTolerance: "±10 lbs/yd² (6 kg/m²)", note: "Control spread rate per lot")
    ]

    public static let weather = WeatherLimits(
        rainWarnIn: 0.01,
        rainBlockIn: 0.10,
        tempWarnMarginF: 5,
        ogfcMinAirTempF: 60,
        tackMinAirTempF: 40,
        wetSurfaceBlocked: true
    )

    public static let wasteOptions: [Double] = [0, 5, 10]

    public static let defaultRoadWidthFt = 12.0
    public static let defaultTruckLoadTons = 18.5
    public static let defaultMachineId = "paver"
    public static let defaultFirstPass = false
    public static let defaultTackApplicationId = "TACK.FIELD_LEVELING"
    public static let defaultWastePct = 0.0
    public static let defaultCourseTypeId = "TOLERANCE.INTERMEDIATE_WEARING"
    /// Seeded by the web job store, not by the YAML `defaults` block.
    public static let defaultThicknessIn = 1.5

    public static func constant(_ id: String) -> Double {
        constantMeta(id).value
    }

    public static func constantMeta(_ id: String) -> ConstantEntry {
        let key = id.hasPrefix("CONST.") ? String(id.dropFirst("CONST.".count)) : id
        guard let entry = constants[key] else {
            preconditionFailure("Unknown constant: \(id)")
        }
        return entry
    }

    /// Unknown ids fall through to the first machine, matching `config.machines[0]`.
    public static func machine(_ id: String) -> MachineEntry {
        machines.first { $0.id == id } ?? machines[0]
    }

    public static func tackField(id: String) -> TackRate {
        tackField.first { $0.id == id } ?? tackField[0]
    }

    public static func minAirTemp(forThickness thicknessIn: Double) -> TempBand {
        let sorted = temperature.sorted { $0.maxThicknessIn < $1.maxThicknessIn }
        return sorted.first { thicknessIn <= $0.maxThicknessIn } ?? sorted[sorted.count - 1]
    }

    /// Null course id uses the job default (intermediate / wearing), matching the web.
    public static func spreadTolerance(for courseId: String?) -> SpreadTolerance {
        if let courseId, let match = spreadTolerance.first(where: { $0.id == courseId }) {
            return match
        }
        if let fallback = spreadTolerance.first(where: { $0.id == defaultCourseTypeId }) {
            return fallback
        }
        return spreadTolerance[0]
    }
}
