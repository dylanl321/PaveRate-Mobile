import SwiftUI
import UIKit
import PaveRateCore

struct BigNumberField: View {
    let label: String
    var hint: String?
    let unit: String
    var numeric: Bool = true
    var placeholder: String? = nil
    /// Set when the screen has to react to the keypad, such as the map end field.
    var focus: FocusState<Bool>.Binding? = nil
    @Binding var text: String

    @Environment(\.fieldPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spokenLabel: String {
        unit.isEmpty ? label : "\(label), \(unit)"
    }

    private var fieldSize: CGFloat {
        palette.fieldPoints * min(OutdoorScale.multiplier(dynamicTypeSize), 1.6)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                entry
                    .layoutPriority(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: palette.minControl)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.border, lineWidth: palette.borderWidth)
            )
            if let hint {
                Text(hint)
                    .font(.body)
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var entry: some View {
        if numeric {
            styled(
                TextField(placeholder ?? "0", text: $text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
            )
        } else {
            styled(
                TextField(placeholder ?? "Name", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            )
        }
    }

    private func styled<V: View>(_ view: V) -> some View {
        view
            .font(.system(size: fieldSize, weight: .bold, design: .rounded))
            .foregroundStyle(palette.text)
            .onSubmit { FieldKeyboard.dismiss() }
            .modifier(OptionalFocus(focus: focus))
            .accessibilityLabel(spokenLabel)
    }
}

private struct OptionalFocus: ViewModifier {
    var focus: FocusState<Bool>.Binding?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

struct ChoiceButton: View {
    let title: String
    var subtitle: String?
    let selected: Bool
    let action: () -> Void

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: palette.minControl)
            .foregroundStyle(selected ? palette.accentText : palette.text)
            .background(selected ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.border, lineWidth: palette.borderWidth)
            )
        }
        .buttonStyle(FieldPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ResultHero: View {
    let value: String?
    let unit: String
    var secondary: String?
    var status: StatusKind?
    var statusText: String?

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let status, let statusText {
                Text(statusText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.onStatus(status))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(palette.status(status), in: Capsule())
                    .accessibilityLabel(statusText)
            }
            Text(value ?? "—")
                .outdoorFont(palette.heroPoints)
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.35)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(value == nil ? "No result yet" : "\(value ?? "") \(unit)")
            Text(unit)
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let secondary {
                Text(secondary)
                    .font(.title3)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.border, lineWidth: palette.borderWidth)
        )
    }
}

struct StatusBanner: View {
    let kind: StatusKind
    let message: String
    var detail: String?

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.title3.weight(.bold))
            if let detail {
                Text(detail)
                    .font(.body)
            }
        }
        .foregroundStyle(palette.onStatus(kind))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.status(kind), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.map { "\(message). \($0)" } ?? message)
    }
}

struct ShowWorkBox: View {
    let steps: [WorkStep]
    var notes: [String] = []
    var emptyFormula: String?

    @Environment(\.fieldPalette) private var palette
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                open.toggle()
            } label: {
                HStack {
                    Text(open ? "Hide your work" : "Show your work")
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    if !steps.isEmpty {
                        Text("\(steps.count)")
                            .font(.headline.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(palette.accent, in: Capsule())
                            .foregroundStyle(palette.accentText)
                    }
                }
                .foregroundStyle(palette.text)
                .frame(minHeight: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(open ? "Hide your work" : "Show your work")

            if open {
                if steps.isEmpty, let emptyFormula {
                    Text(emptyFormula)
                        .font(.title3.monospaced())
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(steps, id: \.step) { step in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(step.step). \(step.label)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.text)
                        Text(step.formula)
                            .font(.title3.monospaced())
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(step.result)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(.body)
                        .foregroundStyle(palette.muted)
                }
            }
        }
        .padding(16)
        .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border, lineWidth: palette.borderWidth)
        )
    }
}

func weatherGlance(_ job: JobSetup) -> String? {
    guard job.airTempF != nil || job.rainNext24hIn != nil || job.surfaceWet else { return nil }
    if job.surfaceWet { return "Surface wet" }
    if let rain = rainCheck(totalRainIn: job.rainNext24hIn), rain.status == .fail {
        return "Rain hold"
    }
    if let rain = rainCheck(totalRainIn: job.rainNext24hIn), rain.status == .warn {
        return "Rain watch"
    }
    guard let air = job.airTempF else { return nil }
    let check = placementCheck(airTempF: air, thicknessIn: job.thicknessIn)
    let word: String
    switch check?.status {
    case .pass:
        word = "temp ok"
    case .warn:
        word = "borderline"
    case .fail:
        word = "too cold"
    case nil:
        word = "temp set"
    }
    return "\(displayNumber(air))°F · \(word)"
}

struct JobStrip: View {
    let job: JobSetup

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.siteName.isEmpty ? "This job" : job.siteName)
                .font(.headline.weight(.bold))
            Text("\(displayNumber(job.widthFt)) ft wide · \(displayNumber(job.thicknessIn)) in · \(FieldFormat.groupedRound(job.targetRateLbsSy)) lbs/SY")
                .font(.title3.weight(.semibold))
            Text(job.course.label)
                .font(.body)
            if let glance = weatherGlance(job) {
                Text(glance)
                    .font(.title3.weight(.bold))
            }
        }
        .foregroundStyle(palette.accentText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.accent, in: RoundedRectangle(cornerRadius: 16))
    }
}

enum FieldKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// Decimal pad has no return key. Every screen that contains a field calls this.
    func fieldKeyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    FieldKeyboard.dismiss()
                }
                .font(.title2.weight(.bold))
                .accessibilityHint("Dismisses the keypad")
            }
        }
    }

    func fieldScroll() -> some View {
        scrollDismissesKeyboard(.interactively)
    }
}

struct FieldPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct FieldSegmented<Value: Hashable>: View {
    let label: String
    let options: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                    FieldHaptics.tap()
                } label: {
                    Text(title(option))
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(56, palette.minControl * 0.72))
                        .foregroundStyle(selected ? palette.accentText : palette.text)
                        .background(selected ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(palette.border, lineWidth: palette.borderWidth)
                        )
                }
                .buttonStyle(FieldPressStyle())
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

struct FieldToggle: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool
    var onTint: Color? = nil

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(onTint ?? palette.good)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: palette.minControl, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: palette.borderWidth))
    }
}

struct FieldWideButton: View {
    let title: String
    var destructive: Bool = false
    let action: () -> Void

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(56, palette.minControl - 12))
                .foregroundStyle(destructive ? palette.bad : palette.text)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(destructive ? palette.bad : palette.border, lineWidth: palette.borderWidth)
                )
        }
        .buttonStyle(FieldPressStyle())
    }
}

struct UseRunLengthButton: View {
    var fill: (String) -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        let feet = model.runMeasure.lengthForCalcs
        if feet > 0 {
            Button("Use map length · \(FieldFormat.groupedRound(feet)) ft") {
                model.checkpoint()
                fill(displayNumber(feet))
                FieldHaptics.tap()
            }
            .buttonStyle(FieldPrimaryButtonStyle())
        }
    }
}

struct SectionLabel: View {
    let text: String
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        Text(text)
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.text)
    }
}
