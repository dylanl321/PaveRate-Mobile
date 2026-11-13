import Foundation

public struct FieldSummary: Equatable, Sendable {
    public var title: String
    public var lines: [String]
    public var plainText: String

    public init(title: String, lines: [String], plainText: String) {
        self.title = title
        self.lines = lines
        self.plainText = plainText
    }
}

public enum FieldSummaryText {
    public static func compose(
        title: String,
        job: JobSetup,
        details: [String],
        now: Date,
        timeZone: TimeZone = .current,
        people: String? = nil
    ) -> FieldSummary {
        var lines = jobHeader(job, now: now, timeZone: timeZone, people: people)
        let body = details.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !body.isEmpty {
            lines.append("")
            lines.append(contentsOf: body)
        }
        lines.append("")
        lines.append("PaveRate field note. Check the ticket before you send it.")
        return FieldSummary(title: title, lines: lines, plainText: ([title] + lines).joined(separator: "\n"))
    }

    public static func daily(
        job: JobSetup,
        weather: WeatherReading?,
        decision: WeatherDecision?,
        run: RunMeasure?,
        loads: [LoadTicket],
        extras: [String] = [],
        photoNotes: [PhotoNote] = [],
        now: Date,
        timeZone: TimeZone = .current,
        people: String? = nil
    ) -> FieldSummary {
        var details: [String] = []
        if let weather, let decision {
            details.append("Weather")
            details.append("Call: \(decision.headline)")
            details.append("Air: \(FieldFormat.jsNumber(weather.airTempF))°F")
            if let wind = weather.windMph {
                let compass = weather.windDirectionDeg.map { " \(GeoMeasure.compassLabel(degrees: $0))" } ?? ""
                details.append("Wind: \(FieldFormat.jsNumber(FieldFormat.jsRound(wind))) mph\(compass)")
            }
            if let ground = weather.groundTempF {
                details.append("Ground forecast: \(FieldFormat.jsNumber(ground))°F (not an IR reading)")
            }
            details.append("Rain next 24 h: \(FieldFormat.fixed(weather.rainNext24hIn, digits: 2)) in")
            let age = WeatherPolicy.ageText(fetchedAt: weather.fetchedAt, now: now)
            details.append("Source: \(WeatherDecisions.sourceLabel(weather.source)), \(age)")
            if weather.suggestsWetSurface {
                details.append("Surface: raining or snowing when this was read")
            }
        }
        if let run, run.lengthForCalcs > 0 {
            details.append("")
            details.append("Run")
            if run.plannedFeet > 0 {
                details.append("Planned: \(FieldFormat.groupedRound(run.plannedFeet)) ft (\(run.stationPlanned))")
            }
            if run.pavedFeet > 0 {
                details.append("Paved: \(FieldFormat.groupedRound(run.pavedFeet)) ft (\(run.stationPaved))")
            }
            if run.plannedFeet > 0 {
                details.append("Left: \(FieldFormat.groupedRound(run.remainingFeet)) ft")
            }
            details.append("Area: \(FieldFormat.groupedRound(run.plannedAreaSqYd > 0 ? run.plannedAreaSqYd : run.pavedAreaSqYd)) SY")
            if run.overrun {
                details.append("Tracked line is longer than the plan.")
            }
        }
        if !loads.isEmpty {
            details.append("")
            details.append("Loads")
            details.append("Tons placed: \(FieldFormat.fixed(LoadLedger.tonsPlaced(loads), digits: 2))")
            for (index, load) in loads.enumerated() {
                details.append(LoadLedger.line(index: index + 1, load: load, job: job))
            }
        }
        if !photoNotes.isEmpty {
            details.append("")
            details.append("Photos")
            for (index, note) in photoNotes.enumerated() {
                details.append(note.line(index: index + 1))
            }
        }
        details.append(contentsOf: extras)
        let title = job.siteName.isEmpty ? "PaveRate" : job.siteName
        return compose(title: title, job: job, details: details, now: now, timeZone: timeZone, people: people)
    }

    private static func jobHeader(_ job: JobSetup, now: Date, timeZone: TimeZone, people: String?) -> [String] {
        let when = timestamp(now, timeZone: timeZone)
        var lines = [when, ""]
        if let people, !people.isEmpty {
            lines.append(people)
        }
        lines.append("\(FieldFormat.jsNumber(job.widthFt)) ft wide · \(FieldFormat.jsNumber(job.thicknessIn)) in · \(FieldFormat.groupedRound(job.targetRateLbsSy)) lbs/SY")
        lines.append(job.course.label)
        lines.append("\(job.machine.label)\(job.firstPass ? " · first pass" : "")")
        if job.wastePct > 0 {
            lines.append("Waste \(FieldFormat.jsNumber(job.wastePct))%")
        }
        return lines
    }

    private static func timestamp(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
    }
}
