import SwiftUI
import PaveRateCore

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @State private var addingLoad = false
    @State private var confirmNewDay = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                JobStrip(job: model.job)
                WeatherStrip()
                runGlance
                loads
                ShareBar(summary: model.dailySummary())
                glareButton
                if model.canUndo {
                    Button("Undo") {
                        model.undoLastChange()
                        FieldHaptics.tap()
                    }
                    .buttonStyle(FieldSecondaryButtonStyle())
                }
            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .navigationTitle("Today")
        .background(palette.background.ignoresSafeArea())
        .sheet(isPresented: $addingLoad) {
            AddLoadSheet()
        }
        .confirmationDialog("Start a new day?", isPresented: $confirmNewDay, titleVisibility: .visible) {
            Button("Clear today's loads and paved track", role: .destructive) {
                model.startNewDay()
                FieldHaptics.tap()
            }
            Button("Keep this day", role: .cancel) {}
        } message: {
            Text("The plan, the width, and the mix stay. Share the note first if you need a copy.")
        }
    }

    private var runGlance: some View {
        let run = model.runMeasure
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Run")
            if run.lengthForCalcs <= 0 {
                Text("Draw the run on the Map tab. The length lands here and in the calculators.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            } else {
                Text("\(FieldFormat.groupedRound(run.lengthForCalcs)) ft")
                    .font(.system(size: palette.heroPoints, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(run.plannedFeet > 0 ? "Plan \(run.stationPlanned) · \(FieldFormat.groupedRound(run.plannedAreaSqYd)) SY" : "Tracked \(run.stationPaved)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
                if run.plannedFeet > 0 {
                    ProgressView(value: min(max(run.fraction, 0), 1))
                        .tint(run.overrun ? palette.warn : palette.good)
                    Text(run.overrun ? "Tracked line is longer than the plan." : "\(FieldFormat.groupedRound(run.remainingFeet)) ft left on the plan")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
            }
        }
    }

    private var loads: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Loads")
            if model.loads.isEmpty {
                Text("No tickets yet. Tons placed on Feet Left come from this list once you add one.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)
            } else {
                Text("\(FieldFormat.fixed(LoadLedger.tonsPlaced(model.loads), digits: 2)) tons placed")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                ForEach(Array(model.loads.enumerated()), id: \.element.id) { index, load in
                    loadRow(index: index + 1, load: load)
                }
            }
            Button("Add load") {
                addingLoad = true
            }
            .buttonStyle(FieldPrimaryButtonStyle())
            if !model.loads.isEmpty || !model.pavedPoints.isEmpty {
                Button("New day") { confirmNewDay = true }
                    .buttonStyle(FieldSecondaryButtonStyle())
            }
        }
    }

    private func loadRow(index: Int, load: LoadTicket) -> some View {
        let yield = LoadLedger.yield(tons: load.tons, coveredFeet: load.coveredFeet, job: model.job)
        return VStack(alignment: .leading, spacing: 6) {
            Text(LoadLedger.line(index: index, load: load, job: model.job))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
            if let guidance = yield.spec?.guidance {
                Text(guidance)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            Button("Remove load") {
                model.deleteLoad(load.id)
                FieldHaptics.tap()
            }
            .font(.headline.weight(.bold))
            .frame(minHeight: 44)
            .foregroundStyle(palette.bad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
    }

    private var glareButton: some View {
        Button(model.appearance == .glare ? "Sunlight" : "Glare mode") {
            model.appearance = model.appearance == .glare ? .sunlight : .glare
            FieldHaptics.tap()
        }
        .buttonStyle(FieldSecondaryButtonStyle())
    }
}

struct AddLoadSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var truck = ""
    @State private var tons = ""
    @State private var feet = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BigNumberField(label: "Truck", hint: "Number on the side of the truck.", unit: "", numeric: false, text: $truck)
                    BigNumberField(label: "Tons on the ticket", unit: "tons", text: $tons)
                    BigNumberField(label: "Feet this load covered", hint: "Optional. Leave blank if you only have the ticket.", unit: "ft", text: $feet)
                    if let yield = preview {
                        if let expected = yield.expectedFeet {
                            Text("Should reach \(FieldFormat.groupedRound(expected)) ft at \(FieldFormat.groupedRound(model.job.targetRateLbsSy)) lbs/SY.")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(palette.text)
                        }
                        if let spec = yield.spec {
                            StatusBanner(kind: spec.status.kind, message: spec.label, detail: spec.guidance)
                        }
                    }
                    Button("Save load") {
                        guard let tonsValue = parseField(tons), tonsValue > 0 else { return }
                        model.addLoad(truck: truck, tons: tonsValue, coveredFeet: parseField(feet))
                        if let status = preview?.spec?.status {
                            FieldHaptics.status(status)
                        } else {
                            FieldHaptics.success()
                        }
                        dismiss()
                    }
                    .buttonStyle(FieldPrimaryButtonStyle())
                }
                .padding(20)
            }
            .navigationTitle("Load")
            .background(palette.background.ignoresSafeArea())
            .fieldKeyboardDone()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.title3.weight(.bold))
                }
            }
        }
    }

    private var preview: LoadYield? {
        guard let tonsValue = parseField(tons), tonsValue > 0 else { return nil }
        return LoadLedger.yield(tons: tonsValue, coveredFeet: parseField(feet), job: model.job)
    }
}
