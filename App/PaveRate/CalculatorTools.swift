import SwiftUI
import PaveRateCore

struct SpreadRateTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        @Bindable var model = model
        let report = AsphaltCalculator.spreadRate(
            tons: parseField(model.inputs.spreadTons),
            distanceFt: parseField(model.inputs.spreadDistance),
            customTargetLbsSy: model.inputs.spreadOverride ? parseField(model.inputs.spreadCustomRate) : nil,
            job: model.job
        )
        PinnedResultStack {
            ResultHero(
                value: report.headline,
                unit: "lbs/SY placed",
                secondary: varianceLine(report),
                status: report.spec?.status.kind,
                statusText: report.spec?.label,
                compact: true
            )
        } content: {
            if let rain = report.rain, rain.status != .pass {
                StatusBanner(kind: rain.status.kind, message: rain.message, detail: rain.guidance)
            }
            if let placement = report.placement, placement.status == .fail {
                StatusBanner(kind: placement.status.kind, message: placement.message, detail: placement.guidance)
            }

            Text("Target from the lift")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
            Text(report.targetLbsSy.map { "\(FieldFormat.groupedRound($0)) lbs/SY" } ?? "Set a thickness on the job")
                .outdoorFont(36)
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            FieldToggle(
                title: "Override target rate",
                detail: "Use a rate you type instead of thickness times 110.",
                isOn: $model.inputs.spreadOverride
            )
            if model.inputs.spreadOverride {
                BigNumberField(label: "Custom target", unit: "lbs/SY", text: $model.inputs.spreadCustomRate)
            }

            BigNumberField(
                label: "Tons placed",
                hint: "Ticket tons for the stretch you are checking.",
                unit: "tons",
                text: $model.inputs.spreadTons
            )
            if let tons = model.tonsPlacedToday, tons > 0 {
                Button("Use tons placed today · \(FieldFormat.fixed(tons, digits: 2))") {
                    model.checkpoint()
                    model.inputs.spreadTons = displayNumber(tons)
                    FieldHaptics.tap()
                }
                .buttonStyle(FieldSecondaryButtonStyle())
            }
            BigNumberField(label: "Distance covered", unit: "ft", text: $model.inputs.spreadDistance)
            UseRunLengthButton { model.inputs.spreadDistance = $0 }


            if let guidance = report.spec?.guidance {
                Text(guidance)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            }

            if let distance = parseField(model.inputs.spreadDistance),
               distance != 0,
               model.job.widthFt != 0,
               let target = report.targetLbsSy {
                Button("Snap tons to target rate") {
                    let tons = tonsToMatchRate(lengthFt: distance, widthFt: model.job.widthFt, rateLbsSy: target)
                    model.checkpoint()
                    model.inputs.spreadTons = displayNumber(tons)
                    FieldHaptics.tap()
                }
                .buttonStyle(FieldPrimaryButtonStyle())
                .accessibilityHint("Fills tons so the placed rate matches the target.")
            }

            ShowWorkBox(
                steps: report.steps,
                notes: report.notes + PaveRateConfig.table12.map { row in
                    "\(row.label): \(row.spreadTolerance)"
                },
                emptyFormula: "rate = (tons − retained) × 2000 ÷ (length × width ÷ 9)"
            )
        }
    }

    private func varianceLine(_ report: SpreadRateReport) -> String? {
        guard let placed = report.placedLbsSy, let target = report.targetLbsSy else {
            return report.targetLbsSy.map { "Target \(FieldFormat.groupedRound($0)) lbs/SY" }
        }
        let variance = placed - target
        let sign = variance > 0 ? "+" : ""
        return "\(sign)\(FieldFormat.fixed(variance, digits: 1)) lbs/SY vs \(FieldFormat.groupedRound(target)) target"
    }
}

struct FeetLeftTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        @Bindable var model = model
        let ordered = parseField(model.inputs.feetOrdered)
        let placed = model.tonsPlacedToday
        let total = parseField(model.inputs.feetTotalLength)
        let report = AsphaltCalculator.feetLeft(
            tonsOrdered: ordered,
            tonsPlaced: placed,
            totalLengthFt: total,
            job: model.job
        )
        let oneTruckFeet: Double? = (report.rateLbsSy > 0 && model.job.widthFt > 0)
            ? feetFromLoads(
                loads: 1,
                tonsPerLoad: model.job.truckLoadTons,
                widthFt: model.job.widthFt,
                rateLbsSy: report.rateLbsSy
            )
            : nil
        PinnedResultStack {
            ResultHero(
                value: report.headline,
                unit: "ft left today",
                secondary: "At \(displayNumber(model.job.widthFt)) ft wide, \(FieldFormat.groupedRound(report.rateLbsSy)) lbs/SY",
                compact: true
            )
        } content: {
            BigNumberField(label: "Tons ordered today", hint: "Plant tickets for the day.", unit: "tons", text: $model.inputs.feetOrdered)
            if model.loads.isEmpty {
                BigNumberField(label: "Tons placed so far", unit: "tons", text: $model.inputs.feetPlaced)
            } else {
                Text("\(FieldFormat.fixed(LoadLedger.tonsPlaced(model.loads), digits: 2)) tons from \(model.loads.count) loads")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
            }
            BigNumberField(label: "Total length", hint: "Optional. Draws a progress bar.", unit: "ft", text: $model.inputs.feetTotalLength)
            UseRunLengthButton { model.inputs.feetTotalLength = $0 }
            if let oneTruckFeet {
                Text("One \(displayNumber(model.job.truckLoadTons))-ton truck reaches \(FieldFormat.groupedRound(oneTruckFeet)) ft at this rate.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            if let total, total > 0, let done = report.completedFeet {
                ProgressView(value: min(max(done / total, 0), 1))
                    .tint(palette.good)
                    .accessibilityLabel("Length paved")
                    .accessibilityValue("\(FieldFormat.groupedRound(done)) of \(FieldFormat.groupedRound(total)) feet")
                Text("\(FieldFormat.groupedRound(done)) of \(FieldFormat.groupedRound(total)) ft")
                    .font(.title3.weight(.semibold))
            }
            ShowWorkBox(
                steps: report.steps,
                notes: report.notes,
                emptyFormula: "feet = (ordered − placed) × 2000 × 9 ÷ (width × rate)"
            )
        }
    }
}

struct DistancePlannerTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        @Bindable var model = model
        let report = AsphaltCalculator.distancePlan(
            tonsInSilo: parseField(model.inputs.plannerSilo),
            tonsInTrucks: parseField(model.inputs.plannerTrucks),
            desiredDistanceFt: parseField(model.inputs.plannerDesired),
            job: model.job
        )
        PinnedResultStack {
            ResultHero(
                value: report.availableFeet.map(FieldFormat.groupedRound),
                unit: "ft available",
                secondary: report.availableTons.map { "From \(FieldFormat.groupedRound($0)) tons total" },
                compact: true
            )
        } content: {
            BigNumberField(label: "Tons in plant silo", unit: "tons", text: $model.inputs.plannerSilo)
            BigNumberField(label: "Tons in trucks headed to the job", unit: "tons", text: $model.inputs.plannerTrucks)
            BigNumberField(label: "Desired distance to cover", unit: "ft", text: $model.inputs.plannerDesired)
            ResultHero(
                value: report.tonsNeeded.map { FieldFormat.fixed($0, digits: 1) },
                unit: "tons needed",
                secondary: parseField(model.inputs.plannerDesired).map { "To cover \(FieldFormat.groupedRound($0)) ft" }
            )
            ShowWorkBox(
                steps: report.steps,
                notes: report.notes,
                emptyFormula: "feet = (silo + trucks) × 2000 × 9 ÷ (width × rate)"
            )
        }
    }
}

struct TonnageTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        @Bindable var model = model
        let report = AsphaltCalculator.tonnage(lengthFt: parseField(model.inputs.tonnageLength), job: model.job)
        PinnedResultStack {
            ResultHero(
                value: report.tons.map { FieldFormat.fixed($0, digits: 1) },
                unit: "tons to order",
                secondary: "Includes \(displayNumber(model.job.wastePct))% waste at \(FieldFormat.groupedRound(report.rateLbsSy)) lbs/SY",
                compact: true
            )
        } content: {
            BigNumberField(label: "Length to pave", unit: "ft", text: $model.inputs.tonnageLength)
            UseRunLengthButton { model.inputs.tonnageLength = $0 }
            ShowWorkBox(
                steps: report.steps,
                notes: report.notes,
                emptyFormula: "tons = (length × width ÷ 9 × rate) ÷ 2000 × (1 + waste%)"
            )
        }
    }
}

struct TackTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        @Bindable var model = model
        let report = AsphaltCalculator.tack(lengthFt: parseField(model.inputs.tackLength), job: model.job)
        PinnedResultStack {
            ResultHero(
                value: report.suggestedGallons,
                unit: report.blocked ? "gal blocked" : "gal at the mid rate",
                secondary: rangeLine(report),
                status: report.blocked ? .bad : nil,
                statusText: report.blocked ? "Do not shoot" : nil,
                compact: true
            )
        } content: {
            BigNumberField(label: "Length to shoot", unit: "ft", text: $model.inputs.tackLength)
            UseRunLengthButton { model.inputs.tackLength = $0 }
            SectionLabel(text: "Application")
            ForEach(PaveRateConfig.tackField) { tack in
                ChoiceButton(
                    title: tack.label,
                    subtitle: "\(displayNumber(tack.min))–\(displayNumber(tack.max)) gal/SY",
                    selected: model.job.tackApplicationId == tack.id
                ) {
                    model.job.tackApplicationId = tack.id
                }
            }
            if let temp = report.temp, temp.status != .pass {
                StatusBanner(kind: temp.status.kind, message: temp.message, detail: temp.guidance)
            } else if let temp = report.temp {
                StatusBanner(kind: temp.status.kind, message: temp.message)
            }
            if let rain = report.rain, rain.status != .pass {
                StatusBanner(kind: rain.status.kind, message: rain.message, detail: rain.guidance)
            }
            if model.job.surfaceWet {
                StatusBanner(kind: .bad, message: "Surface is wet — do not tack.")
            }
            ShowWorkBox(
                steps: report.steps,
                notes: report.notes,
                emptyFormula: "gallons = (length × width ÷ 9) × shot rate"
            )
        }
    }

    private func rangeLine(_ report: TackReport) -> String? {
        guard let min = report.gallonsMin, let max = report.gallonsMax, !report.blocked else { return nil }
        return "Range \(FieldFormat.groupedRound(min))–\(FieldFormat.groupedRound(max)) gal"
    }
}

struct StickCheckTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        @Bindable var model = model
        let report = AsphaltCalculator.stick(compactedIn: parseField(model.inputs.stickTarget))
        PinnedResultStack {
            ResultHero(value: report.headline, unit: "in loose behind the screed", compact: true)
        } content: {
            BigNumberField(
                label: "Target compacted thickness",
                hint: "What the mat should be after the rollers.",
                unit: "in",
                text: $model.inputs.stickTarget
            )
            ShowWorkBox(
                steps: report.steps,
                notes: report.notes,
                emptyFormula: "loose = compacted × \(FieldFormat.jsNumber(report.factor))"
            )
        }
    }
}

struct PavingWindowTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        let report = AsphaltCalculator.pavingWindow(job: model.job)
        PinnedResultStack {
            ResultHero(
                value: report.headline,
                unit: "minimum air temp for this lift",
                secondary: model.job.airTempF.map { "Air is \(displayNumber($0))°F" },
                status: report.check?.status.kind,
                statusText: badge(report),
                compact: true
            )
        } content: {
            WeatherStrip()
            if model.job.airTempF == nil {
                Text("Enter the air temperature in job setup to check this lift. Tap the job name at the top of Calc.")
                    .font(.title3)
                    .foregroundStyle(palette.text)
            }
            if let check = report.check {
                StatusBanner(kind: check.status.kind, message: check.message, detail: check.guidance)
            }
            if let openGraded = report.openGraded {
                StatusBanner(kind: openGraded.status.kind, message: openGraded.message)
            }
            SectionLabel(text: "Table 4")
            ForEach(PaveRateConfig.temperature) { band in
                let active = report.matchedBand?.id == band.id
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up to \(displayNumber(band.maxThicknessIn)) in")
                        .font(.title3.weight(.bold))
                    Text("\(displayNumber(band.minAirTempF))°F minimum")
                        .font(.title2.weight(.bold))
                    if let note = band.note {
                        Text(note)
                            .font(.body)
                    }
                }
                .foregroundStyle(active ? palette.accentText : palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(palette.cardPadding)
                .background(active ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
            }
            ShowWorkBox(steps: [], notes: report.notes, emptyFormula: "Table lookup — no arithmetic")
        }
    }

    private func badge(_ report: PavingWindowReport) -> String? {
        guard let check = report.check else { return nil }
        switch check.status {
        case .pass: return "Safe to pave"
        case .warn: return "Borderline"
        case .fail: return "Too cold"
        }
    }
}

struct MillingTool: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @AppStorage("paverate.mill.length") private var lengthText = ""
    @AppStorage("paverate.mill.depth") private var depthText = "2"
    @AppStorage("paverate.mill.density") private var densityText = "2"

    var body: some View {
        let result = MillingCalculator.calculate(
            lengthFt: parseField(lengthText) ?? 0,
            widthFt: model.job.widthFt,
            depthIn: parseField(depthText) ?? 0,
            densityTonsPerCubicYard: parseField(densityText) ?? 0,
            truckTons: model.job.truckLoadTons
        )
        PinnedResultStack {
            ResultHero(
                value: result.map { FieldFormat.fixed($0.tons, digits: 1) },
                unit: "tons removed",
                secondary: result.map {
                    "\(FieldFormat.groupedRound($0.squareYards)) SY · \(FieldFormat.fixed($0.truckloads, digits: 1)) loads · one truck covers \(FieldFormat.groupedRound($0.feetPerTruck)) ft"
                },
                compact: true
            )
        } content: {
            Text("Width and truck size come from the job. Density is a field estimate, about 2 tons per cubic yard for asphalt millings.")
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.text)
            BigNumberField(label: "Length to mill", unit: "ft", text: $lengthText)
            UseRunLengthButton { lengthText = $0 }
            BigNumberField(label: "Depth", unit: "in", text: $depthText)
            BigNumberField(label: "Density", hint: "Tons per cubic yard. About 2 for asphalt millings.", unit: "tons/CY", text: $densityText)
        }
    }
}
