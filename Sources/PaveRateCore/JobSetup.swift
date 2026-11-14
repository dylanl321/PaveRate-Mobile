import Foundation

/// Shared job values every asphalt calculator reads.
/// Defaults match the web job store (`src/lib/stores/job.svelte.ts`).
public struct JobSetup: Codable, Equatable, Sendable {
    public var siteName: String
    public var widthFt: Double
    public var thicknessIn: Double
    public var machineId: String
    public var firstPass: Bool
    public var truckLoadTons: Double
    public var tackApplicationId: String
    public var wastePct: Double
    public var courseTypeId: String
    /// Manual air temperature. The web fills this from weather when online.
    public var airTempF: Double?
    /// Manual forecast total for the next 24 hours, inches.
    public var rainNext24hIn: Double?
    /// Offline stand-in for the web's live "raining now" flag.
    public var surfaceWet: Bool

    public init(
        siteName: String = "",
        widthFt: Double = PaveRateConfig.defaultRoadWidthFt,
        thicknessIn: Double = PaveRateConfig.defaultThicknessIn,
        machineId: String = PaveRateConfig.defaultMachineId,
        firstPass: Bool = PaveRateConfig.defaultFirstPass,
        truckLoadTons: Double = PaveRateConfig.defaultTruckLoadTons,
        tackApplicationId: String = PaveRateConfig.defaultTackApplicationId,
        wastePct: Double = PaveRateConfig.defaultWastePct,
        courseTypeId: String = PaveRateConfig.defaultCourseTypeId,
        airTempF: Double? = nil,
        rainNext24hIn: Double? = nil,
        surfaceWet: Bool = false
    ) {
        self.siteName = siteName
        self.widthFt = widthFt
        self.thicknessIn = thicknessIn
        self.machineId = machineId
        self.firstPass = firstPass
        self.truckLoadTons = truckLoadTons
        self.tackApplicationId = tackApplicationId
        self.wastePct = wastePct
        self.courseTypeId = courseTypeId
        self.airTempF = airTempF
        self.rainNext24hIn = rainNext24hIn
        self.surfaceWet = surfaceWet
    }

    public var targetRateLbsSy: Double {
        thicknessIn > 0 ? spreadRateFromThickness(thicknessIn) : 0
    }

    public var machine: MachineEntry {
        PaveRateConfig.machine(machineId)
    }

    public var tackApplication: TackRate {
        PaveRateConfig.tackField(id: tackApplicationId)
    }

    public var course: SpreadTolerance {
        PaveRateConfig.spreadTolerance(for: courseTypeId)
    }
}

public enum FieldTool: String, CaseIterable, Codable, Sendable, Identifiable {
    case spreadRate
    case feetLeft
    case distancePlanner
    case tonnage
    case tack
    case stickCheck
    case milling
    case pavingWindow

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .spreadRate: return "Spread Rate"
        case .feetLeft: return "Feet Left Today"
        case .distancePlanner: return "Distance Planner"
        case .tonnage: return "Tonnage to Order"
        case .tack: return "Tack Rate"
        case .stickCheck: return "Stick Check"
        case .milling: return "Milling"
        case .pavingWindow: return "Paving Window"
        }
    }

    public var blurb: String {
        switch self {
        case .spreadRate: return "Am I putting down the right rate?"
        case .feetLeft: return "How many feet are left today?"
        case .distancePlanner: return "How far will these tons go?"
        case .tonnage: return "How many tons should I order?"
        case .tack: return "How much tack do I need?"
        case .stickCheck: return "Is the loose mat the right height?"
        case .milling: return "How many tons and trucks will milling make?"
        case .pavingWindow: return "Is it warm enough to pave?"
        }
    }
}

public struct WorkStep: Equatable, Sendable {
    public let step: Int
    public let label: String
    public let formula: String
    public let result: String

    public init(step: Int, label: String, formula: String, result: String) {
        self.step = step
        self.label = label
        self.formula = formula
        self.result = result
    }
}
