import SwiftUI
import PaveRateCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    @State private var windText = ""
    @State private var strongText = ""
    @State private var plantText = ""
    @State private var widthText = ""
    @State private var thicknessText = ""

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("These stay on this phone. The mix math stays in feet, tons, pounds per square yard, and °F.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.text)

                SectionLabel(text: "Names on the share note")
                BigNumberField(label: "Foreman", unit: "", numeric: false, text: $model.settings.foremanName)
                BigNumberField(label: "Crew", unit: "", numeric: false, text: $model.settings.crewName)

                SectionLabel(text: "Run length")
                Text("The big number on the map. Stations are the same feet, written as 12+50.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                Picker("Length", selection: $model.settings.lengthDisplay) {
                    ForEach(LengthDisplay.allCases, id: \.self) { display in
                        Text(display.title).tag(display)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .accessibilityLabel("Length display")

                SectionLabel(text: "Wind note")
                Text("A field note, not a GDOT cutoff. Tack is not blocked by wind.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                BigNumberField(label: "Note starts at", unit: "mph", text: $windText)
                BigNumberField(label: "Strong note starts at", unit: "mph", text: $strongText)

                SectionLabel(text: "Call the plant")
                Text("Alerts when tons left are at or under this, or when placed tons pass the order.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                BigNumberField(label: "Tons left", unit: "tons", text: $plantText)

                SectionLabel(text: "Default job")
                BigNumberField(label: "Width", unit: "ft", text: $widthText)
                BigNumberField(label: "Thickness", unit: "in", text: $thicknessText)
                Text("Course")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
                ForEach(PaveRateConfig.spreadTolerance) { course in
                    ChoiceButton(
                        title: course.label,
                        selected: model.settings.defaultCourseTypeId == course.id
                    ) {
                        model.settings.defaultCourseTypeId = course.id
                    }
                }
                Text("Machine")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
                ForEach(PaveRateConfig.machines) { machine in
                    ChoiceButton(
                        title: machine.label,
                        selected: model.settings.defaultMachineId == machine.id
                    ) {
                        model.settings.defaultMachineId = machine.id
                    }
                }
                Button("Apply defaults to this job") {
                    syncNumbers()
                    model.applyJobDefaults()
                    FieldHaptics.tap()
                }
                .buttonStyle(FieldPrimaryButtonStyle())
                .accessibilityHint("Copies width, thickness, course, and machine onto the job. Asks for nothing else.")

                Toggle(isOn: $model.settings.preferGlare) {
                    Text("Glare is the default")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.text)
                }
                .tint(palette.good)
                .onChange(of: model.settings.preferGlare) { _, on in
                    if on { model.appearance = .glare }
                }

                Toggle(isOn: $model.consoleOn) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lock Screen")
                            .font(.title3.weight(.bold))
                        Text("Feet left, tons left, and the go or hold call while the phone is on the paver.")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(palette.text)
                }
                .tint(palette.good)

                Text("The Lock Screen updates from the app itself. The Home Screen widget stays on “Open PaveRate” until the App Group \(FieldBoardStore.appGroupID) is on both app ids. The steps are in the README. The archive does not require that group.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            .padding(20)
        }
        .fieldScroll()
        .navigationTitle("Settings")
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .onAppear(perform: loadDrafts)
        .onChange(of: windText) { _, _ in syncNumbers() }
        .onChange(of: strongText) { _, _ in syncNumbers() }
        .onChange(of: plantText) { _, _ in syncNumbers() }
        .onChange(of: widthText) { _, _ in syncNumbers() }
        .onChange(of: thicknessText) { _, _ in syncNumbers() }
    }

    private func loadDrafts() {
        windText = displayNumber(model.settings.windNoteMph)
        strongText = displayNumber(model.settings.strongWindMph)
        plantText = displayNumber(model.settings.plantCallTons)
        widthText = displayNumber(model.settings.defaultWidthFt)
        thicknessText = displayNumber(model.settings.defaultThicknessIn)
    }

    private func syncNumbers() {
        if let value = parseField(windText), value >= 0 { model.settings.windNoteMph = value }
        if let value = parseField(strongText), value >= 0 { model.settings.strongWindMph = value }
        if let value = parseField(plantText), value >= 0 { model.settings.plantCallTons = value }
        if let value = parseField(widthText), value >= 0 { model.settings.defaultWidthFt = value }
        if let value = parseField(thicknessText), value >= 0 { model.settings.defaultThicknessIn = value }
    }
}
