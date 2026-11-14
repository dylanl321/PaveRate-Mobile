import SwiftUI
import UIKit
import PaveRateCore

struct BigNumberField: View {
    let label: String
    var hint: String?
    let unit: String
    var numeric: Bool = true
    @Binding var text: String

    @Environment(\.fieldPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.text)
            HStack(spacing: 12) {
                TextField(numeric ? "0" : "Name", text: $text)
                    .keyboardType(numeric ? .decimalPad : .default)
                    .textInputAutocapitalization(numeric ? .never : .words)
                    .font(.system(size: palette.fieldPoints, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(label)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(palette.muted)
                }
            }
            .padding(.horizontal, 16)
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
            }
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
            .frame(minHeight: palette.minControl)
            .foregroundStyle(selected ? palette.accentText : palette.text)
            .background(selected ? palette.accent : palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.border, lineWidth: palette.borderWidth)
            )
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(palette.status(status), in: Capsule())
                    .accessibilityLabel(statusText)
            }
            Text(value ?? "—")
                .font(.system(size: palette.heroPoints, weight: .bold, design: .rounded))
                .foregroundStyle(palette.text)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .accessibilityLabel(value ?? "No result yet")
            Text(unit)
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.muted)
            if let secondary {
                Text(secondary)
                    .font(.title3)
                    .foregroundStyle(palette.text)
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
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(palette.status(kind), in: RoundedRectangle(cornerRadius: 14))
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
                }
                ForEach(steps, id: \.step) { step in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(step.step). \(step.label)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(palette.text)
                        Text(step.formula)
                            .font(.title3.monospaced())
                            .foregroundStyle(palette.text)
                        Text(step.result)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.text)
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

extension View {
    func fieldKeyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .font(.title3.weight(.bold))
            }
        }
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
