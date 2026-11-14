import Foundation
import PaveRateCore

extension AppModel {
    func dailySummary(now: Date = Date()) -> FieldSummary {
        var extras: [String] = []
        if let feet = feetReport().feet {
            extras.append("Feet left: \(FieldFormat.groupedRound(feet)) ft")
        }
        if let spread = spreadReport().spec {
            extras.append("Spread check: \(spread.label)")
        }
        return FieldSummaryText.daily(
            job: job,
            weather: cachedWeather,
            decision: weatherDecision,
            run: runMeasure.lengthForCalcs > 0 ? runMeasure : nil,
            loads: loads,
            extras: extras,
            now: now
        )
    }

    func summary(for tool: FieldTool) -> FieldSummary {
        var details: [String] = []
        switch tool {
        case .spreadRate:
            let report = spreadReport()
            if let placed = report.headline {
                details.append("Placed rate: \(placed) lbs/SY")
            }
            if let spec = report.spec {
                details.append(spec.label)
                if let guidance = spec.guidance { details.append(guidance) }
            }
        case .feetLeft:
            let report = feetReport()
            if let feet = report.headline {
                details.append("Feet left: \(feet) ft")
            }
            if let tons = tonsPlacedToday {
                details.append("Tons placed: \(FieldFormat.fixed(tons, digits: 2))")
            }
        case .distancePlanner:
            let report = distanceReport()
            if let feet = report.availableFeet {
                details.append("Available: \(FieldFormat.groupedRound(feet)) ft")
            }
            if let tons = report.tonsNeeded {
                details.append("Tons needed: \(FieldFormat.fixed(tons, digits: 1))")
            }
        case .tonnage:
            let report = AsphaltCalculator.tonnage(lengthFt: parseField(inputs.tonnageLength), job: job)
            if let tons = report.tons {
                details.append("Tons to order: \(FieldFormat.fixed(tons, digits: 1))")
            }
        case .tack:
            let report = AsphaltCalculator.tack(lengthFt: parseField(inputs.tackLength), job: job)
            if report.blocked {
                details.append("Tack: do not shoot")
            } else if let gallons = report.suggestedGallons {
                details.append("Tack: \(gallons) gal at the mid rate")
            }
        case .stickCheck:
            let report = AsphaltCalculator.stick(compactedIn: parseField(inputs.stickTarget))
            if let loose = report.headline {
                details.append("Loose height: \(loose) in")
            }
        case .pavingWindow:
            if let decision = weatherDecision {
                details.append(decision.headline)
            }
            let report = AsphaltCalculator.pavingWindow(job: job)
            if let check = report.check {
                details.append(check.message)
            }
        }
        let title = job.siteName.isEmpty ? tool.title : "\(job.siteName) — \(tool.title)"
        return FieldSummaryText.compose(title: title, job: job, details: details, now: Date())
    }

    func spreadReport() -> SpreadRateReport {
        AsphaltCalculator.spreadRate(
            tons: parseField(inputs.spreadTons),
            distanceFt: parseField(inputs.spreadDistance),
            customTargetLbsSy: inputs.spreadOverride ? parseField(inputs.spreadCustomRate) : nil,
            job: job
        )
    }

    func feetReport() -> FeetLeftReport {
        AsphaltCalculator.feetLeft(
            tonsOrdered: parseField(inputs.feetOrdered),
            tonsPlaced: tonsPlacedToday,
            totalLengthFt: parseField(inputs.feetTotalLength),
            job: job
        )
    }

    func distanceReport() -> DistancePlanReport {
        AsphaltCalculator.distancePlan(
            tonsInSilo: parseField(inputs.plannerSilo),
            tonsInTrucks: parseField(inputs.plannerTrucks),
            desiredDistanceFt: parseField(inputs.plannerDesired),
            job: job
        )
    }
}
