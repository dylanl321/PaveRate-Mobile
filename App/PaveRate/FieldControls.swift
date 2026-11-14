import SwiftUI
import UIKit
import PaveRateCore

struct BigNumberField: View {
    let label: String
    var hint: String?
    let unit: String
    var numeric: Bool = true
    var placeholder: String? = nil
    @Binding var text: String
    /// The map uses this to shrink while the keypad is up.
    var onFocusChange: ((Bool) -> Void)? = nil
    /// Done commits the field, then runs this. The map places the end here.
    var onSubmit: (() -> Void)? = nil

    @Environment(\.fieldPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focused: Bool

    private var spokenLabel: String {
        unit.isEmpty ? label : "\(label), \(unit)"
    }

    private var fieldSize: CGFloat {
        palette.fieldPoints * palette.fontScale * min(OutdoorScale.multiplier(dynamicTypeSize), palette.fieldTypeCap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: palette.tightSpacing) {
            Text(label)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: palette.tightSpacing) {
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
            .padding(.horizontal, palette.cardPadding)
            .padding(.vertical, palette.tightSpacing)
            .frame(minHeight: palette.minControl)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: palette.cornerRadius)
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
            )
        }
    }

    private func styled<V: View>(_ view: V) -> some View {
        view
            .font(.system(size: fieldSize, weight: .bold, design: .rounded))
            .foregroundStyle(palette.text)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { FieldKeyboard.done() }
            .onChange(of: focused) { _, isOn in
                onFocusChange?(isOn)
                if isOn { registerSubmit() }
            }
            .accessibilityLabel(spokenLabel)
    }

    private func registerSubmit() {
        let binding = $text
        let submit = onSubmit
        let isNumeric = numeric
        FieldKeyboard.submit = {
            if isNumeric, let value = parseField(binding.wrappedValue) {
                let shown = displayNumber(value)
                if binding.wrappedValue != shown {
                    binding.wrappedValue = shown
                }
            }
            submit?()
        }
    }
}

/// One keypad Done button. It commits the number, runs the screen's submit, then closes.
@MainActor
enum FieldKeyboard {
    static var submit: (() -> Void)?

    static func done() {
        let action = submit
        submit = nil
        action?()
        dismiss()
    }

    static func dismiss() {
        submit = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

/// Closes the keypad when the tap is not on the field or a button. The map tap uses this too.
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = uiView.window, context.coordinator.recognizer == nil else { return }
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = context.coordinator
            window.addGestureRecognizer(tap)
            context.coordinator.recognizer = tap
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let tap = coordinator.recognizer {
            tap.view?.removeGestureRecognizer(tap)
            coordinator.recognizer = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var recognizer: UITapGestureRecognizer?

        @objc func dismiss() {
            DispatchQueue.main.async {
                FieldKeyboard.dismiss()
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view: UIView? = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UIControl { return false }
                let name = NSStringFromClass(type(of: current))
                if name.contains("Keyboard") || name.contains("Input") { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
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
            .background(selected ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: palette.cornerRadius)
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
    /// Pinned at the top of a calculator: the number and unit share a line so the inputs keep room.
    var compact: Bool = false

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if let status, let statusText {
                StatusPill(kind: status, text: statusText)
            }
            if compact {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    valueText(points: palette.heroPoints * 0.72)
                    unitText
                }
            } else {
                valueText(points: palette.heroPoints)
                unitText
            }
            if let secondary {
                Text(secondary)
                    .font(compact ? .body.weight(.semibold) : .title3)
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(palette.cardPadding)
        .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: palette.cornerRadius)
                .stroke(palette.border, lineWidth: palette.borderWidth)
        )
        .accessibilityElement(children: .combine)
    }

    private func valueText(points: CGFloat) -> some View {
        Text(value ?? "—")
            .outdoorFont(points)
            .foregroundStyle(palette.text)
            .minimumScaleFactor(0.35)
            .lineLimit(compact ? 1 : 2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(value == nil ? "No result yet" : "\(value ?? "") \(unit)")
    }

    private var unitText: some View {
        Text(unit)
            .font(.title2.weight(.semibold))
            .foregroundStyle(palette.muted)
            .lineLimit(compact ? 2 : nil)
            .minimumScaleFactor(compact ? 0.6 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
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
        .padding(palette.cardPadding)
        .background(palette.status(kind), in: RoundedRectangle(cornerRadius: palette.cornerRadius))
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
        VStack(alignment: .leading, spacing: palette.tightSpacing) {
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
                .frame(minHeight: palette.keypadHeight)
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
                    .padding(palette.cardPadding)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                }
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(.body)
                        .foregroundStyle(palette.muted)
                }
            }
        }
        .padding(palette.cardPadding)
        .background(palette.surfaceAlt, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: palette.cornerRadius)
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
        .padding(palette.cardPadding)
        .background(palette.accent, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
    }
}

struct KeypadDoneButton: View {
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        Button("Done") { FieldKeyboard.done() }
            .font(.title2.weight(.bold))
            .padding(.horizontal, palette.cardPadding)
            .padding(.vertical, palette.tightSpacing)
            .frame(minWidth: palette.minControl * 1.7, minHeight: palette.keypadHeight)
            .foregroundStyle(palette.accentText)
            .background(palette.accent, in: Capsule())
            .accessibilityLabel("Done")
            .accessibilityHint("Saves this number and closes the keypad.")
    }
}

extension View {
    /// Number pads have no return key. One Done button, on the screens that contain a field.
    func fieldKeyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                KeypadDoneButton()
            }
        }
    }

    func fieldScroll() -> some View {
        scrollDismissesKeyboard(.interactively)
    }

    func installKeyboardDismiss() -> some View {
        background(KeyboardDismissInstaller())
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
        HStack(spacing: palette.tightSpacing) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                    FieldHaptics.tap()
                } label: {
                    Text(title(option))
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: palette.keypadHeight)
                        .foregroundStyle(selected ? palette.accentText : palette.text)
                        .background(selected ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: palette.cornerRadius)
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
        .padding(palette.cardPadding)
        .frame(maxWidth: .infinity, minHeight: palette.minControl, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.border, lineWidth: palette.borderWidth))
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
                .frame(minHeight: max(palette.keypadHeight, palette.minControl - 12))
                .foregroundStyle(destructive ? palette.bad : palette.text)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: palette.cornerRadius)
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

// MARK: - Screen mode, toast, pinned result

/// Sunlight, Glare, and Night from the top bar of every tab. Field or Compact stays in Settings.
struct ScreenModeMenu: View {
    @Environment(AppModel.self) private var model

    private var icon: String {
        switch model.appearance {
        case .sunlight: return "sun.max"
        case .glare: return "sun.max.fill"
        case .night: return "moon.fill"
        }
    }

    var body: some View {
        Menu {
            ForEach(FieldAppearance.allCases, id: \.self) { mode in
                Button {
                    model.appearance = mode
                    FieldHaptics.tap()
                } label: {
                    if mode == model.appearance {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Screen: \(model.appearance.title)")
        .accessibilityHint("Switches between Sunlight, Glare, and Night.")
    }
}

extension View {
    /// Puts the screen mode switch in the top bar.
    func screenModeToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ScreenModeMenu()
            }
        }
    }
}

/// A word on a status color. Used on the Today hero and on pinned results.
struct StatusPill: View {
    let kind: StatusKind
    let text: String

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        Text(text)
            .font(.headline.weight(.bold))
            .foregroundStyle(palette.onStatus(kind))
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(palette.status(kind), in: Capsule())
            .accessibilityLabel(text)
    }
}

/// Short note after a change, with Undo. Sits above the bottom bar for six seconds.
struct UndoToast: View {
    let message: String
    var canUndo: Bool = true
    let undo: () -> Void

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        HStack(spacing: palette.tightSpacing) {
            Text(message)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.background)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if canUndo {
                Button("Undo", action: undo)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.accentText)
                    .padding(.horizontal, 18)
                    .frame(minHeight: max(palette.keypadHeight, 48))
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: palette.cornerRadius - 2))
                    .buttonStyle(FieldPressStyle())
                    .accessibilityHint("Puts back the last change.")
            }
        }
        .padding(.leading, palette.cardPadding)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(palette.text, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
        .accessibilityElement(children: .contain)
    }
}

/// The calculator's answer stays at the top of the screen while the inputs scroll under it.
struct PinnedResultStack<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        LazyVStack(alignment: .leading, spacing: palette.stackSpacing, pinnedViews: [.sectionHeaders]) {
            Section {
                content
            } header: {
                header
                    .padding(.bottom, palette.tightSpacing)
                    .background(palette.background)
            }
        }
    }
}
