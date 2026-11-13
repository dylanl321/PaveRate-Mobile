import Foundation

public enum SpreadSpecStatus: String, Sendable, Equatable {
    case good
    case warn
    case bad
}

public struct SpreadSpecCheck: Sendable, Equatable {
    public let status: SpreadSpecStatus
    public let toleranceLbsSy: Double
    public let deltaLbsSy: Double
    public let label: String
    public let courseLabel: String
    public let message: String
    public let clause: String
    public let clauseTitle: String
    public let guidance: String?

    public init(
        status: SpreadSpecStatus,
        toleranceLbsSy: Double,
        deltaLbsSy: Double,
        label: String,
        courseLabel: String,
        message: String,
        clause: String,
        clauseTitle: String,
        guidance: String? = nil
    ) {
        self.status = status
        self.toleranceLbsSy = toleranceLbsSy
        self.deltaLbsSy = deltaLbsSy
        self.label = label
        self.courseLabel = courseLabel
        self.message = message
        self.clause = clause
        self.clauseTitle = clauseTitle
        self.guidance = guidance
    }
}

public enum PlacementStatus: String, Sendable, Equatable {
    case pass
    case warn
    case fail
}

public struct PlacementCheck: Sendable, Equatable {
    public let status: PlacementStatus
    public let minTempF: Double
    public let message: String
    public let clause: String
    public let clauseTitle: String
    public let guidance: String?

    public init(
        status: PlacementStatus,
        minTempF: Double,
        message: String,
        clause: String,
        clauseTitle: String,
        guidance: String? = nil
    ) {
        self.status = status
        self.minTempF = minTempF
        self.message = message
        self.clause = clause
        self.clauseTitle = clauseTitle
        self.guidance = guidance
    }
}

public struct RainCheck: Sendable, Equatable {
    public let status: PlacementStatus
    public let totalIn: Double
    public let message: String
    public let clause: String
    public let clauseTitle: String
    public let guidance: String?

    public init(
        status: PlacementStatus,
        totalIn: Double,
        message: String,
        clause: String,
        clauseTitle: String,
        guidance: String? = nil
    ) {
        self.status = status
        self.totalIn = totalIn
        self.message = message
        self.clause = clause
        self.clauseTitle = clauseTitle
        self.guidance = guidance
    }
}

public struct TackTempCheck: Sendable, Equatable {
    public let status: PlacementStatus
    public let message: String
    public let clause: String
    public let clauseTitle: String
    public let guidance: String?

    public init(
        status: PlacementStatus,
        message: String,
        clause: String,
        clauseTitle: String,
        guidance: String? = nil
    ) {
        self.status = status
        self.message = message
        self.clause = clause
        self.clauseTitle = clauseTitle
        self.guidance = guidance
    }
}

public struct CourseAirTempCheck: Sendable, Equatable {
    public let status: PlacementStatus
    public let message: String
    public let label: String

    public init(status: PlacementStatus, message: String, label: String) {
        self.status = status
        self.message = message
        self.label = label
    }
}

/// GDOT Table 12. Inside ±tolerance = good; within 1.5× tolerance = warn; beyond = bad.
public func spreadSpecCheck(
    placedLbsSy: Double?,
    targetLbsSy: Double?,
    courseId: String?
) -> SpreadSpecCheck? {
    guard let placedLbsSy, let targetLbsSy, targetLbsSy > 0 else { return nil }
    let tol = PaveRateConfig.spreadTolerance(for: courseId)
    let delta = placedLbsSy - targetLbsSy
    let absDelta = abs(delta)
    let direction = delta > 0 ? "high" : "low"
    let off = "\(FieldFormat.fixed(FieldFormat.jsRound(absDelta), digits: 0)) lbs/SY \(direction)"
    let clause = "§400.4.A.2.b Table 12"
    let clauseTitle = "Spread Rate Tolerance"

    if absDelta <= tol.toleranceLbsSy {
        return SpreadSpecCheck(
            status: .good,
            toleranceLbsSy: tol.toleranceLbsSy,
            deltaLbsSy: delta,
            label: "In spec",
            courseLabel: tol.label,
            message: "Within ±\(FieldFormat.jsNumber(tol.toleranceLbsSy)) lbs/SY (Table 12, \(tol.label))",
            clause: clause,
            clauseTitle: clauseTitle
        )
    }
    if absDelta <= tol.toleranceLbsSy * 1.5 {
        return SpreadSpecCheck(
            status: .warn,
            toleranceLbsSy: tol.toleranceLbsSy,
            deltaLbsSy: delta,
            label: "Marginal — \(off)",
            courseLabel: tol.label,
            message: "\(off); tolerance is ±\(FieldFormat.jsNumber(tol.toleranceLbsSy)) lbs/SY (Table 12, \(tol.label))",
            clause: clause,
            clauseTitle: clauseTitle,
            guidance: "Adjust tons or distance to bring rate within tolerance before the next load."
        )
    }
    return SpreadSpecCheck(
        status: .bad,
        toleranceLbsSy: tol.toleranceLbsSy,
        deltaLbsSy: delta,
        label: "Out of spec — \(off)",
        courseLabel: tol.label,
        message: "\(off); exceeds ±\(FieldFormat.jsNumber(tol.toleranceLbsSy)) lbs/SY (Table 12, \(tol.label))",
        clause: clause,
        clauseTitle: clauseTitle,
        guidance: "Stop and re-calibrate paver head before continuing. Document deviation on daily report."
    )
}

/// GDOT Table 4 minimum air temperature for the lift thickness.
public func placementCheck(airTempF: Double?, thicknessIn: Double) -> PlacementCheck? {
    guard let airTempF, thicknessIn > 0 else { return nil }
    let entry = PaveRateConfig.minAirTemp(forThickness: thicknessIn)
    let margin = PaveRateConfig.weather.tempWarnMarginF
    let clause = "§400.3.05.E Table 4"
    let clauseTitle = "HMA Lift Thickness — Weather Limitations"
    if airTempF >= entry.minAirTempF {
        return PlacementCheck(
            status: .pass,
            minTempF: entry.minAirTempF,
            message: "Air temp OK for \(FieldFormat.jsNumber(thicknessIn))\" lift (min \(FieldFormat.jsNumber(entry.minAirTempF))°F per Table 4)",
            clause: clause,
            clauseTitle: clauseTitle
        )
    }
    if airTempF >= entry.minAirTempF - margin {
        return PlacementCheck(
            status: .warn,
            minTempF: entry.minAirTempF,
            message: "Borderline — \(FieldFormat.jsNumber(airTempF))°F is within \(FieldFormat.jsNumber(margin))°F of \(FieldFormat.jsNumber(entry.minAirTempF))°F minimum for \(FieldFormat.jsNumber(thicknessIn))\" lift",
            clause: clause,
            clauseTitle: clauseTitle,
            guidance: "Monitor closely — if temp drops further, suspend paving per GDOT §400.3.05.E."
        )
    }
    return PlacementCheck(
        status: .fail,
        minTempF: entry.minAirTempF,
        message: "Too cold — \(FieldFormat.jsNumber(airTempF))°F is below \(FieldFormat.jsNumber(entry.minAirTempF))°F minimum for \(FieldFormat.jsNumber(thicknessIn))\" lift",
        clause: clause,
        clauseTitle: clauseTitle,
        guidance: "Suspend paving. Air temp is below the GDOT Table 4 minimum for this lift thickness."
    )
}

/// Tack coat air temperature — GDOT §413.3.05.A requires ≥ 40°F.
/// Exactly 40°F is a warning (within 5°F of the minimum), matching the web.
public func tackTempCheck(airTempF: Double?) -> TackTempCheck? {
    guard let airTempF else { return nil }
    let minTemp = PaveRateConfig.weather.tackMinAirTempF
    let clause = "§413.3.05.A"
    let clauseTitle = "Tack Coat — Seasonal & Weather Limitation"
    if airTempF < minTemp {
        return TackTempCheck(
            status: .fail,
            message: "Too cold for tack coat — §413.3.05.A requires air temp ≥ \(FieldFormat.jsNumber(minTemp))°F in shade",
            clause: clause,
            clauseTitle: clauseTitle,
            guidance: "Do not apply tack coat until air temperature reaches the required minimum."
        )
    }
    if airTempF < minTemp + 5 {
        return TackTempCheck(
            status: .warn,
            message: "Borderline for tack — air temp is near \(FieldFormat.jsNumber(minTemp))°F minimum",
            clause: clause,
            clauseTitle: clauseTitle,
            guidance: "Monitor temperature closely before applying tack coat."
        )
    }
    return TackTempCheck(
        status: .pass,
        message: "Air temp OK for tack coat (min \(FieldFormat.jsNumber(minTemp))°F)",
        clause: clause,
        clauseTitle: clauseTitle
    )
}

/// Rain forecast check. Warn at 0.01 in, block at 0.10 in.
public func rainCheck(totalRainIn: Double?) -> RainCheck? {
    guard let totalRainIn else { return nil }
    let shown = FieldFormat.fixed(totalRainIn, digits: 2)
    let clause = "§400.3.05.E"
    let clauseTitle = "HMA Weather Limitations — Wet/Frozen Surface"
    if totalRainIn >= PaveRateConfig.weather.rainBlockIn {
        return RainCheck(
            status: .fail,
            totalIn: totalRainIn,
            message: "\(shown) in rain forecast — do not pave or tack on wet surfaces",
            clause: clause,
            clauseTitle: clauseTitle,
            guidance: "Hold paving and tack. Do not pave or apply tack on wet or frozen surfaces."
        )
    }
    if totalRainIn >= PaveRateConfig.weather.rainWarnIn {
        return RainCheck(
            status: .warn,
            totalIn: totalRainIn,
            message: "\(shown) in rain forecast — watch tack timing and surface moisture",
            clause: clause,
            clauseTitle: clauseTitle,
            guidance: "Delay tack coat until surface dries. Check surface moisture before resuming."
        )
    }
    return RainCheck(
        status: .pass,
        totalIn: totalRainIn,
        message: "No significant rain in next 24 h (\(shown) in)",
        clause: clause,
        clauseTitle: clauseTitle
    )
}

/// OGFC / PEM air-temperature floor from Section 400.3.05.E (60°F).
///
/// The web paving-window card compares the course id to the literals `"ogfc"` and `"pem"`.
/// Job setup stores `TOLERANCE.OGFC` / `TOLERANCE.PEM`, so that check never runs there.
/// This function accepts both the literals and the Table 12 ids.
public func openGradedAirTempCheck(airTempF: Double?, courseId: String?) -> CourseAirTempCheck? {
    guard let airTempF, let courseId, let label = openGradedLabel(courseId) else { return nil }
    let minTemp = PaveRateConfig.weather.ogfcMinAirTempF
    let margin = PaveRateConfig.weather.tempWarnMarginF
    if airTempF >= minTemp {
        return CourseAirTempCheck(
            status: .pass,
            message: "Air temp OK for \(label) (min \(FieldFormat.jsNumber(minTemp))°F)",
            label: label
        )
    }
    if airTempF >= minTemp - margin {
        return CourseAirTempCheck(
            status: .warn,
            message: "Borderline for \(label) — \(FieldFormat.jsNumber(airTempF))°F is near \(FieldFormat.jsNumber(minTemp))°F minimum",
            label: label
        )
    }
    return CourseAirTempCheck(
        status: .fail,
        message: "Too cold for \(label) — \(FieldFormat.jsNumber(airTempF))°F is below \(FieldFormat.jsNumber(minTemp))°F minimum",
        label: label
    )
}

func openGradedLabel(_ courseId: String) -> String? {
    switch courseId {
    case "ogfc", "OGFC", "TOLERANCE.OGFC":
        return "OGFC"
    case "pem", "PEM", "TOLERANCE.PEM":
        return "PEM"
    default:
        return nil
    }
}
