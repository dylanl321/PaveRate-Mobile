import Foundation

public struct SpreadRateReport: Equatable, Sendable {
    public let targetLbsSy: Double?
    public let placedLbsSy: Double?
    public let spec: SpreadSpecCheck?
    public let retainTons: Double
    public let placement: PlacementCheck?
    public let rain: RainCheck?
    public let steps: [WorkStep]
    public let notes: [String]
    public var headline: String? {
        guard let placedLbsSy else { return nil }
        return FieldFormat.groupedRound(placedLbsSy)
    }
}

public struct FeetLeftReport: Equatable, Sendable {
    public let rateLbsSy: Double
    public let feet: Double?
    public let completedFeet: Double?
    public let steps: [WorkStep]
    public let notes: [String]
    public var headline: String? {
        guard let feet else { return nil }
        return FieldFormat.groupedRound(feet)
    }
}

public struct DistancePlanReport: Equatable, Sendable {
    public let rateLbsSy: Double
    public let availableTons: Double?
    public let availableFeet: Double?
    public let tonsNeeded: Double?
    public let steps: [WorkStep]
    public let notes: [String]
}

public struct TonnageReport: Equatable, Sendable {
    public let rateLbsSy: Double
    public let tons: Double?
    public let steps: [WorkStep]
    public let notes: [String]
    public var headline: String? {
        guard let tons else { return nil }
        return FieldFormat.groupedRound(tons)
    }
}

public struct TackReport: Equatable, Sendable {
    public let application: TackRate
    public let gallonsMin: Double?
    public let gallonsMid: Double?
    public let gallonsMax: Double?
    public let blocked: Bool
    public let temp: TackTempCheck?
    public let rain: RainCheck?
    public let steps: [WorkStep]
    public let notes: [String]
    public var suggestedGallons: String? {
        guard let gallonsMid, !blocked else { return nil }
        return FieldFormat.groupedRound(gallonsMid)
    }
}

public struct StickReport: Equatable, Sendable {
    public let looseIn: Double?
    public let factor: Double
    public let steps: [WorkStep]
    public let notes: [String]
    public var headline: String? {
        guard let looseIn else { return nil }
        return FieldFormat.fixed(looseIn, digits: 2)
    }
}

public struct PavingWindowReport: Equatable, Sendable {
    public let check: PlacementCheck?
    public let openGraded: CourseAirTempCheck?
    public let matchedBand: TempBand?
    public let notes: [String]
    public var headline: String? {
        guard let check else { return nil }
        return "\(FieldFormat.jsNumber(check.minTempF))°F"
    }
}

public enum AsphaltCalculator {
    /// Zero is treated as missing for tons and distance, matching the web's truthy checks.
    public static func spreadRate(
        tons: Double?,
        distanceFt: Double?,
        customTargetLbsSy: Double?,
        job: JobSetup
    ) -> SpreadRateReport {
        let target: Double?
        if let customTargetLbsSy, customTargetLbsSy > 0 {
            target = customTargetLbsSy
        } else if job.thicknessIn > 0 {
            target = spreadRateFromThickness(job.thicknessIn)
        } else {
            target = nil
        }

        let retain = job.firstPass ? job.machine.retainTons : 0
        let placed: Double?
        if let tons, tons != 0, let distanceFt, distanceFt != 0, job.widthFt != 0 {
            placed = spreadRatePlaced(
                tons: tons,
                lengthFt: distanceFt,
                widthFt: job.widthFt,
                machineId: job.machineId,
                firstPass: job.firstPass
            )
        } else {
            placed = nil
        }

        let spec = spreadSpecCheck(placedLbsSy: placed, targetLbsSy: target, courseId: job.courseTypeId)
        let placement = placementCheck(airTempF: job.airTempF, thicknessIn: job.thicknessIn)
        let rain = rainCheck(totalRainIn: job.rainNext24hIn)

        var steps: [WorkStep] = []
        if let tons, let distanceFt, job.widthFt != 0, let target, let placed {
            let area = squareYards(distanceFt, job.widthFt)
            let netTons = tons - retain
            let pounds = netTons * PaveRateConfig.constant("CONST.LB_PER_TON")
            let poundsFormula: String
            if retain > 0 {
                poundsFormula = "(\(FieldFormat.fixed(tons, digits: 2)) − \(FieldFormat.fixed(retain, digits: 2))) × 2000"
            } else {
                poundsFormula = "\(FieldFormat.fixed(tons, digits: 2)) × 2000"
            }
            let targetFormula: String
            let targetResult: String
            if let customTargetLbsSy, customTargetLbsSy > 0 {
                targetFormula = "custom target"
                targetResult = "\(FieldFormat.fixed(FieldFormat.jsRound(target), digits: 0)) lbs/SY"
            } else {
                targetFormula = "\(FieldFormat.fixed(job.thicknessIn, digits: 2)) × 110"
                targetResult = "\(FieldFormat.fixed(FieldFormat.jsRound(target), digits: 0)) lbs/SY"
            }
            let variance = placed - target
            let varianceSign = variance > 0 ? "+" : ""
            steps = [
                WorkStep(
                    step: 1,
                    label: "Area in square yards",
                    formula: "\(FieldFormat.fixed(distanceFt, digits: 0)) × \(FieldFormat.fixed(job.widthFt, digits: 0)) ÷ 9",
                    result: "\(FieldFormat.fixed(area, digits: 2)) SY"
                ),
                WorkStep(
                    step: 2,
                    label: "Pounds placed",
                    formula: poundsFormula,
                    result: "\(FieldFormat.fixed(pounds, digits: 0)) lbs"
                ),
                WorkStep(
                    step: 3,
                    label: "Placed rate",
                    formula: "\(FieldFormat.fixed(pounds, digits: 0)) ÷ \(FieldFormat.fixed(area, digits: 2))",
                    result: "\(FieldFormat.fixed(FieldFormat.jsRound(placed), digits: 0)) lbs/SY"
                ),
                WorkStep(
                    step: 4,
                    label: "Target rate",
                    formula: targetFormula,
                    result: targetResult
                ),
                WorkStep(
                    step: 5,
                    label: "Variance",
                    formula: "\(FieldFormat.fixed(FieldFormat.jsRound(placed), digits: 0)) − \(FieldFormat.fixed(FieldFormat.jsRound(target), digits: 0))",
                    result: "\(varianceSign)\(FieldFormat.fixed(variance, digits: 1)) lbs/SY"
                )
            ]
        }

        let tolerance = PaveRateConfig.spreadTolerance(for: job.courseTypeId)
        var notes = [
            "In-spec is GDOT Section 400 Table 12. \(tolerance.label) must stay within ±\(FieldFormat.jsNumber(tolerance.toleranceLbsSy)) lbs/SY of the target.",
            "Target rate uses the field rule of thumb: thickness (in) × \(FieldFormat.jsNumber(PaveRateConfig.constant("CONST.THICK_MULT"))) lbs/SY."
        ]
        if retain > 0 {
            notes.append("First pass subtracts \(FieldFormat.jsNumber(retain)) tons retained in the \(job.machine.label.lowercased()).")
        }
        return SpreadRateReport(
            targetLbsSy: target,
            placedLbsSy: placed,
            spec: spec,
            retainTons: retain,
            placement: placement,
            rain: rain,
            steps: steps,
            notes: notes
        )
    }

    public static func feetLeft(
        tonsOrdered: Double?,
        tonsPlaced: Double?,
        totalLengthFt: Double?,
        job: JobSetup
    ) -> FeetLeftReport {
        let rate = job.thicknessIn > 0 ? spreadRateFromThickness(job.thicknessIn) : 0
        let feet: Double?
        if rate > 0, job.widthFt > 0, let tonsOrdered, let tonsPlaced {
            feet = feetFromOrderedMinusPlaced(
                tonsOrdered: tonsOrdered,
                tonsPlaced: tonsPlaced,
                widthFt: job.widthFt,
                rateLbsSy: rate
            )
        } else {
            feet = nil
        }
        let completed: Double?
        if let totalLengthFt, let feet, totalLengthFt > 0 {
            completed = max(0, totalLengthFt - feet)
        } else {
            completed = nil
        }

        var steps: [WorkStep] = []
        if let tonsOrdered, let tonsPlaced, job.widthFt != 0, rate != 0, let feet {
            let remaining = tonsOrdered - tonsPlaced
            let remainingLbs = remaining * PaveRateConfig.constant("CONST.LB_PER_TON")
            steps = [
                WorkStep(
                    step: 1,
                    label: "Spread rate",
                    formula: "\(FieldFormat.fixed(job.thicknessIn, digits: 2)) × 110",
                    result: "\(FieldFormat.fixed(rate, digits: 0)) lbs/SY"
                ),
                WorkStep(
                    step: 2,
                    label: "Remaining tons",
                    formula: "\(FieldFormat.fixed(tonsOrdered, digits: 2)) − \(FieldFormat.fixed(tonsPlaced, digits: 2))",
                    result: "\(FieldFormat.fixed(remaining, digits: 2)) tons"
                ),
                WorkStep(
                    step: 3,
                    label: "Remaining lbs",
                    formula: "\(FieldFormat.fixed(remaining, digits: 2)) × 2000",
                    result: "\(FieldFormat.fixed(remainingLbs, digits: 0)) lbs"
                ),
                WorkStep(
                    step: 4,
                    label: "Feet left",
                    formula: "\(FieldFormat.fixed(remainingLbs, digits: 0)) × 9 ÷ (\(FieldFormat.fixed(job.widthFt, digits: 0)) × \(FieldFormat.fixed(rate, digits: 0)))",
                    result: "\(FieldFormat.fixed(feet, digits: 0)) ft"
                )
            ]
        }

        return FeetLeftReport(
            rateLbsSy: rate,
            feet: feet,
            completedFeet: completed,
            steps: steps,
            notes: [
                "Feet = (ordered − placed) × 2000 × 9 ÷ (width × rate).",
                "Rate is thickness × \(FieldFormat.jsNumber(PaveRateConfig.constant("CONST.THICK_MULT"))) lbs/SY per inch."
            ]
        )
    }

    public static func distancePlan(
        tonsInSilo: Double?,
        tonsInTrucks: Double?,
        desiredDistanceFt: Double?,
        job: JobSetup
    ) -> DistancePlanReport {
        let rate = job.thicknessIn > 0 ? spreadRateFromThickness(job.thicknessIn) : 0
        let available: Double?
        if let tonsInSilo, let tonsInTrucks {
            available = tonsInSilo + tonsInTrucks
        } else {
            available = nil
        }
        let availableFeet: Double?
        if let available, rate > 0, job.widthFt > 0 {
            availableFeet = feetFromTons(available, widthFt: job.widthFt, rateLbsSy: rate)
        } else {
            availableFeet = nil
        }
        let tonsNeeded: Double?
        if let desiredDistanceFt, rate > 0, job.widthFt > 0 {
            let denom = PaveRateConfig.constant("CONST.LB_PER_TON") * PaveRateConfig.constant("CONST.SF_PER_SY")
            tonsNeeded = (desiredDistanceFt * job.widthFt * rate) / denom
        } else {
            tonsNeeded = nil
        }

        var steps: [WorkStep] = []
        var index = 1
        if let available, let availableFeet {
            steps.append(WorkStep(
                step: index,
                label: "Available tons",
                formula: "\(FieldFormat.fixed(tonsInSilo ?? 0, digits: 2)) + \(FieldFormat.fixed(tonsInTrucks ?? 0, digits: 2))",
                result: "\(FieldFormat.fixed(available, digits: 2)) tons"
            ))
            index += 1
            steps.append(WorkStep(
                step: index,
                label: "Available distance",
                formula: "\(FieldFormat.fixed(available, digits: 2)) × 2000 × 9 ÷ (\(FieldFormat.fixed(job.widthFt, digits: 0)) × \(FieldFormat.fixed(rate, digits: 0)))",
                result: "\(FieldFormat.fixed(availableFeet, digits: 0)) ft"
            ))
            index += 1
        }
        if let desiredDistanceFt, let tonsNeeded {
            steps.append(WorkStep(
                step: index,
                label: "Tons needed",
                formula: "\(FieldFormat.fixed(desiredDistanceFt, digits: 0)) × \(FieldFormat.fixed(job.widthFt, digits: 0)) × \(FieldFormat.fixed(rate, digits: 0)) ÷ (2000 × 9)",
                result: "\(FieldFormat.fixed(tonsNeeded, digits: 2)) tons"
            ))
        }

        return DistancePlanReport(
            rateLbsSy: rate,
            availableTons: available,
            availableFeet: availableFeet,
            tonsNeeded: tonsNeeded,
            steps: steps,
            notes: [
                "Available distance: feet = (plant silo + trucks) × 2000 × 9 ÷ (width × rate).",
                "Tons needed reverses it: tons = desired feet × width × rate ÷ (2000 × 9).",
                "Uses shared width and the target rate from lift thickness."
            ]
        )
    }

    public static func tonnage(lengthFt: Double?, job: JobSetup) -> TonnageReport {
        let rate = job.thicknessIn > 0 ? spreadRateFromThickness(job.thicknessIn) : 0
        let tons: Double?
        if let lengthFt, lengthFt != 0, rate > 0, job.widthFt > 0 {
            tons = tonnageToOrder(
                lengthFt: lengthFt,
                widthFt: job.widthFt,
                rateLbsSy: rate,
                wastePct: job.wastePct
            )
        } else {
            tons = nil
        }

        var steps: [WorkStep] = []
        if let lengthFt, lengthFt != 0, job.widthFt > 0, rate > 0, let tons {
            let area = squareYards(lengthFt, job.widthFt)
            let base = (area * rate) / PaveRateConfig.constant("CONST.LB_PER_TON")
            let wasteFactor = 1 + job.wastePct / 100
            steps = [
                WorkStep(
                    step: 1,
                    label: "Area in square yards",
                    formula: "\(FieldFormat.fixed(lengthFt, digits: 0)) × \(FieldFormat.fixed(job.widthFt, digits: 0)) ÷ 9",
                    result: "\(FieldFormat.fixed(area, digits: 2)) SY"
                ),
                WorkStep(
                    step: 2,
                    label: "Spread rate",
                    formula: "\(FieldFormat.fixed(job.thicknessIn, digits: 2)) × 110",
                    result: "\(FieldFormat.fixed(rate, digits: 0)) lbs/SY"
                ),
                WorkStep(
                    step: 3,
                    label: "Base tons",
                    formula: "\(FieldFormat.fixed(area, digits: 2)) × \(FieldFormat.fixed(rate, digits: 0)) ÷ 2000",
                    result: "\(FieldFormat.fixed(base, digits: 2)) tons"
                ),
                WorkStep(
                    step: 4,
                    label: "With waste",
                    formula: "\(FieldFormat.fixed(base, digits: 2)) × \(FieldFormat.fixed(wasteFactor, digits: 2))",
                    result: "\(FieldFormat.fixed(tons, digits: 2)) tons"
                )
            ]
        }

        return TonnageReport(
            rateLbsSy: rate,
            tons: tons,
            steps: steps,
            notes: [
                "Includes \(FieldFormat.jsNumber(job.wastePct))% ordering waste.",
                "Spread rate is thickness × 110."
            ]
        )
    }

    public static func tack(lengthFt: Double?, job: JobSetup) -> TackReport {
        let selected = job.tackApplication
        let areaReady = lengthFt != nil && lengthFt != 0 && job.widthFt != 0
        let minGal = areaReady ? tackGallons(lengthFt ?? 0, job.widthFt, selected.min) : nil
        let midGal = areaReady ? tackGallons(lengthFt ?? 0, job.widthFt, selected.mid) : nil
        let maxGal = areaReady ? tackGallons(lengthFt ?? 0, job.widthFt, selected.max) : nil
        let temp = tackTempCheck(airTempF: job.airTempF)
        let rain = rainCheck(totalRainIn: job.rainNext24hIn)
        let blocked = PaveRateConfig.weather.wetSurfaceBlocked && (
            rain?.status == .fail || job.surfaceWet || temp?.status == .fail
        )

        var steps: [WorkStep] = []
        if let lengthFt, job.widthFt != 0, let midGal {
            let area = squareYards(lengthFt, job.widthFt)
            steps = [
                WorkStep(
                    step: 1,
                    label: "Area in square yards",
                    formula: "\(FieldFormat.fixed(lengthFt, digits: 0)) × \(FieldFormat.fixed(job.widthFt, digits: 0)) ÷ 9",
                    result: "\(FieldFormat.fixed(area, digits: 2)) SY"
                ),
                WorkStep(
                    step: 2,
                    label: "Mid rate",
                    formula: "(\(FieldFormat.fixed(selected.min, digits: 3)) + \(FieldFormat.fixed(selected.max, digits: 3))) ÷ 2",
                    result: "\(FieldFormat.fixed(selected.mid, digits: 3)) gal/SY"
                ),
                WorkStep(
                    step: 3,
                    label: "Gallons",
                    formula: "\(FieldFormat.fixed(area, digits: 2)) × \(FieldFormat.fixed(selected.mid, digits: 3))",
                    result: "\(FieldFormat.fixed(FieldFormat.jsRound(midGal), digits: 0)) gal"
                )
            ]
        }

        let specLines = PaveRateConfig.tackSpec.map { rate in
            "\(rate.label): \(FieldFormat.jsNumber(rate.min))–\(FieldFormat.jsNumber(rate.max)) gal/yd² (GDOT Table 2)"
        }
        return TackReport(
            application: selected,
            gallonsMin: minGal,
            gallonsMid: midGal,
            gallonsMax: maxGal,
            blocked: blocked,
            temp: temp,
            rain: rain,
            steps: steps,
            notes: [
                "\(selected.label): \(FieldFormat.jsNumber(selected.min))–\(FieldFormat.jsNumber(selected.max)) gal/SY. Suggested amount is the mid-rate.",
                "No anionic or cationic emulsion under OGFC or PEM on interstates or limited-access routes."
            ] + specLines
        )
    }

    public static func stick(compactedIn: Double?) -> StickReport {
        let factor = PaveRateConfig.constant("CONST.STICK_FACTOR")
        let loose = (compactedIn != nil && (compactedIn ?? 0) > 0) ? stickCheck(compactedIn ?? 0) : nil
        var steps: [WorkStep] = []
        if let compactedIn, compactedIn > 0, let loose {
            steps = [
                WorkStep(
                    step: 1,
                    label: "Loose height",
                    formula: "\(FieldFormat.fixed(compactedIn, digits: 2)) × \(FieldFormat.jsNumber(factor))",
                    result: "\(FieldFormat.fixed(loose, digits: 2)) in"
                )
            ]
        }
        return StickReport(
            looseIn: loose,
            factor: factor,
            steps: steps,
            notes: [
                "Loose height behind the screed = compacted thickness × \(FieldFormat.jsNumber(factor)).",
                "The running config uses 1.25. An older field-card writeup still says 1.2; this app follows the config and its tests."
            ]
        )
    }

    public static func pavingWindow(job: JobSetup) -> PavingWindowReport {
        let check = placementCheck(airTempF: job.airTempF, thicknessIn: job.thicknessIn)
        let openGraded = openGradedAirTempCheck(airTempF: job.airTempF, courseId: job.courseTypeId)
        let band = job.thicknessIn > 0 ? PaveRateConfig.minAirTemp(forThickness: job.thicknessIn) : nil
        var notes = [
            "GDOT §400.3.05.E Table 4 is a lookup, not a formula. The row is the smallest max-thickness that still covers this lift.",
            "Lifts thicker than 8 in. use the 4.1–8 in. row (32°F and rising; base must not be frozen).",
            "OGFC and PEM also have a 60°F floor. With an MTV, the spec allows 55°F when the engineer approves it. This check uses the 60°F floor."
        ]
        if let band {
            notes.insert(
                "Matched row \(band.id): lifts up to \(FieldFormat.jsNumber(band.maxThicknessIn)) in. require \(FieldFormat.jsNumber(band.minAirTempF))°F.",
                at: 0
            )
        }
        return PavingWindowReport(check: check, openGraded: openGraded, matchedBand: band, notes: notes)
    }
}
