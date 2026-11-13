import SwiftUI
import PaveRateCore

struct JobSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    @State private var widthText = ""
    @State private var thicknessText = ""
    @State private var truckText = ""
    @State private var airText = ""
    @State private var rainText = ""

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Screen")
                    Picker("Screen", selection: $model.appearance) {
                        ForEach(FieldAppearance.allCases, id: \.self) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 44)
                }

                BigNumberField(
                    label: "Job name",
                    hint: "Optional. Shows on every calculator.",
                    unit: "",
                    numeric: false,
                    text: $model.job.siteName
                )

                labeledStepper(
                    label: "Mat width",
                    unit: "ft",
                    text: $widthText,
                    hint: "Width of the mat being placed. Used by spread rate, feet left, tack, tonnage, and the distance planner."
                ) { delta in
                    model.job.widthFt = max(0, model.job.widthFt + delta)
                    widthText = displayNumber(model.job.widthFt)
                }

                labeledStepper(
                    label: "Target lift thickness",
                    unit: "in",
                    text: $thicknessText,
                    hint: "Compacted thickness. Target spread rate is thickness × 110 lbs/SY.",
                    step: 0.25
                ) { delta in
                    model.job.thicknessIn = max(0, model.job.thicknessIn + delta)
                    thicknessText = displayNumber(model.job.thicknessIn)
                }

                derivedRate

                SectionLabel(text: "Course type")
                Text("Sets the GDOT Table 12 spread-rate tolerance.")
                    .font(.body)
                    .foregroundStyle(palette.muted)
                ForEach(PaveRateConfig.spreadTolerance) { course in
                    ChoiceButton(
                        title: course.label,
                        subtitle: "±\(displayNumber(course.toleranceLbsSy)) lbs/SY",
                        selected: model.job.courseTypeId == course.id
                    ) {
                        model.job.courseTypeId = course.id
                    }
                }

                SectionLabel(text: "Machine")
                Text("Retained tons are subtracted from the spread-rate check on the first pass.")
                    .font(.body)
                    .foregroundStyle(palette.muted)
                ForEach(PaveRateConfig.machines) { machine in
                    ChoiceButton(
                        title: machine.label,
                        subtitle: machine.retainTons > 0 ? "Holds \(displayNumber(machine.retainTons)) tons" : "No retention",
                        selected: model.job.machineId == machine.id
                    ) {
                        model.job.machineId = machine.id
                    }
                }

                Toggle(isOn: $model.job.firstPass) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First pass")
                            .font(.title3.weight(.bold))
                        Text("Subtract hopper or buggy tons from the actual spread rate.")
                            .font(.body)
                            .foregroundStyle(palette.muted)
                    }
                }
                .tint(palette.good)
                .padding(16)
                .frame(minHeight: 72)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))

                BigNumberField(
                    label: "Truck load size",
                    hint: "Feet left uses this to show how far one truck reaches. Remaining feet for the day still come from ordered tons minus tons placed.",
                    unit: "tons",
                    text: $truckText
                )

                SectionLabel(text: "Tack application")
                ForEach(PaveRateConfig.tackField) { tack in
                    ChoiceButton(
                        title: tack.label,
                        subtitle: "\(displayNumber(tack.min))–\(displayNumber(tack.max)) gal/SY",
                        selected: model.job.tackApplicationId == tack.id
                    ) {
                        model.job.tackApplicationId = tack.id
                    }
                }

                SectionLabel(text: "Ordering waste")
                HStack(spacing: 10) {
                    ForEach(PaveRateConfig.wasteOptions, id: \.self) { option in
                        ChoiceButton(
                            title: "\(displayNumber(option))%",
                            selected: model.job.wastePct == option
                        ) {
                            model.job.wastePct = option
                        }
                    }
                }

                SectionLabel(text: "Air and surface")
                Text("Optional. Enter what you see on site. Nothing here needs a network.")
                    .font(.body)
                    .foregroundStyle(palette.muted)
                BigNumberField(label: "Air temperature", unit: "°F", text: $airText)
                BigNumberField(
                    label: "Rain in the next 24 hours",
                    hint: "Warns at 0.01 in. Blocks paving and tack at 0.10 in.",
                    unit: "in",
                    text: $rainText
                )
                Toggle(isOn: $model.job.surfaceWet) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Surface is wet")
                            .font(.title3.weight(.bold))
                        Text("Blocks tack. Do not shoot tack on a wet or frozen surface.")
                            .font(.body)
                            .foregroundStyle(palette.muted)
                    }
                }
                .tint(palette.bad)
                .padding(16)
                .frame(minHeight: 72)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))

                if let placement = placementCheck(airTempF: model.job.airTempF, thicknessIn: model.job.thicknessIn) {
                    StatusBanner(kind: placement.status.kind, message: placement.message, detail: placement.guidance)
                }
                if let openGraded = openGradedAirTempCheck(airTempF: model.job.airTempF, courseId: model.job.courseTypeId) {
                    StatusBanner(kind: openGraded.status.kind, message: openGraded.message)
                }
            }
            .padding(20)
        }
        .navigationTitle("Job")
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .onAppear(perform: loadDrafts)
        .onChange(of: widthText) { _, newValue in
            if let value = parseField(newValue) { model.job.widthFt = value }
        }
        .onChange(of: thicknessText) { _, newValue in
            if let value = parseField(newValue) { model.job.thicknessIn = value }
        }
        .onChange(of: truckText) { _, newValue in
            if let value = parseField(newValue) { model.job.truckLoadTons = value }
        }
        .onChange(of: airText) { _, newValue in
            model.job.airTempF = parseField(newValue)
        }
        .onChange(of: rainText) { _, newValue in
            model.job.rainNext24hIn = parseField(newValue)
        }
    }

    private var derivedRate: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target spread rate")
                .font(.headline.weight(.bold))
            Text("\(FieldFormat.groupedRound(model.job.targetRateLbsSy)) lbs/SY")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Mix rule of thumb: 110 lbs/SY per inch of compacted thickness. Not a lab density.")
                .font(.body)
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
    }

    private func labeledStepper(
        label: String,
        unit: String,
        text: Binding<String>,
        hint: String,
        step: Double = 1,
        apply: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BigNumberField(label: label, hint: hint, unit: unit, text: text)
            HStack(spacing: 12) {
                stepButton(title: "− \(displayNumber(step))", action: { apply(-step) })
                stepButton(title: "+ \(displayNumber(step))", action: { apply(step) })
            }
        }
    }

    private func stepButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 64)
                .foregroundStyle(palette.accentText)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func loadDrafts() {
        widthText = displayNumber(model.job.widthFt)
        thicknessText = displayNumber(model.job.thicknessIn)
        truckText = displayNumber(model.job.truckLoadTons)
        airText = model.job.airTempF.map(displayNumber) ?? ""
        rainText = model.job.rainNext24hIn.map(displayNumber) ?? ""
    }
}
