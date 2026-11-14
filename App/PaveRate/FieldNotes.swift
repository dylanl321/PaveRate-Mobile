import Foundation
import PaveRateCore

extension AppModel {
    func dailySummary(now: Date = Date()) -> FieldSummary {
        summary(
            job: job,
            weather: cachedWeather,
            loads: loads,
            planned: plannedPoints,
            paved: pavedPoints,
            photos: photoNotes,
            ordered: parseField(inputs.feetOrdered),
            note: dayNote,
            people: settings.peopleLine,
            now: now
        )
    }

    func summary(for archive: DayArchive) -> FieldSummary {
        var settings = FieldSettings()
        settings.foremanName = archive.foremanName
        settings.crewName = archive.crewName
        var extras: [String] = []
        if let ordered = archive.tonsOrdered {
            extras.append("Tons ordered: \(FieldFormat.fixed(ordered, digits: 2))")
        }
        let trimmed = archive.dayNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            extras.append(trimmed)
        }
        let run = GeoMeasure.measure(planned: archive.plannedPoints, paved: archive.pavedPoints, widthFt: archive.job.widthFt)
        let decision = archive.weather.map {
            WeatherDecisions.decide(reading: $0, job: archive.job, windNoteMph: self.settings.windNoteMph, strongWindMph: max(self.settings.strongWindMph, self.settings.windNoteMph))
        }
        return FieldSummaryText.daily(
            job: archive.job,
            weather: archive.weather,
            decision: decision,
            run: run.lengthForCalcs > 0 ? run : nil,
            loads: archive.loads,
            extras: extras,
            photoNotes: archive.photoNotes,
            now: archive.savedAt,
            people: settings.peopleLine
        )
    }

    private func summary(
        job: JobSetup,
        weather: WeatherReading?,
        loads: [LoadTicket],
        planned: [GeoPoint],
        paved: [GeoPoint],
        photos: [PhotoNote],
        ordered: Double?,
        note: String,
        people: String?,
        now: Date
    ) -> FieldSummary {
        var extras: [String] = []
        if let feet = feetReport().feet {
            extras.append("Feet left: \(FieldFormat.groupedRound(feet)) ft")
        }
        if let spread = spreadReport().spec {
            extras.append("Spread check: \(spread.label)")
        }
        if let ordered {
            extras.append("Tons ordered: \(FieldFormat.fixed(ordered, digits: 2))")
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            extras.append(trimmed)
        }
        let run = GeoMeasure.measure(planned: planned, paved: paved, widthFt: job.widthFt)
        let decision = weather.map {
            WeatherDecisions.decide(
                reading: $0,
                job: job,
                windNoteMph: settings.windNoteMph,
                strongWindMph: max(settings.strongWindMph, settings.windNoteMph)
            )
        }
        return FieldSummaryText.daily(
            job: job,
            weather: weather,
            decision: decision,
            run: run.lengthForCalcs > 0 ? run : nil,
            loads: loads,
            extras: extras,
            photoNotes: photos,
            now: now,
            people: people
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
        case .milling:
            if let result = MillingCalculator.calculate(
                lengthFt: parseField(UserDefaults.standard.string(forKey: "paverate.mill.length") ?? "") ?? 0,
                widthFt: job.widthFt,
                depthIn: parseField(UserDefaults.standard.string(forKey: "paverate.mill.depth") ?? "") ?? 0,
                densityTonsPerCubicYard: parseField(UserDefaults.standard.string(forKey: "paverate.mill.density") ?? "") ?? 0,
                truckTons: job.truckLoadTons
            ) {
                details.append("Milling: \(FieldFormat.fixed(result.tons, digits: 1)) tons · \(FieldFormat.fixed(result.truckloads, digits: 1)) loads")
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
