import SwiftUI
import PaveRateCore

struct ToolListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    private let groups: [ToolGroup] = [
        ToolGroup(title: "Check the mat", tools: [.spreadRate, .stickCheck]),
        ToolGroup(title: "Plan the day", tools: [.feetLeft, .distancePlanner, .tonnage, .milling]),
        ToolGroup(title: "Conditions", tools: [.tack, .pavingWindow])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                JobStrip(job: model.job)
                Text("Shared setup is on the Job tab. Every calculator uses it.")
                    .font(.body)
                    .foregroundStyle(palette.muted)

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: palette.tightSpacing) {
                        Text(group.title)
                            .font(.headline.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(palette.muted)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(Array(group.tools.enumerated()), id: \.element) { index, tool in
                                if index > 0 {
                                    Rectangle()
                                        .fill(palette.border)
                                        .frame(height: palette.borderWidth)
                                }
                                toolRow(tool)
                            }
                        }
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: palette.cornerRadius)
                                .stroke(palette.border, lineWidth: palette.borderWidth)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
                    }
                }
            }
            .padding(palette.pagePadding)
        }
        .fieldScroll()
        .navigationTitle("Calc")
        .background(palette.background.ignoresSafeArea())
        .screenModeToolbar()
    }

    private func toolRow(_ tool: FieldTool) -> some View {
        let glance = ToolGlance.make(tool, model: model)
        return NavigationLink {
            CalculatorScreen(tool: tool)
        } label: {
            HStack(alignment: .center, spacing: palette.tightSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(.title3.weight(.bold))
                    Text(tool.blurb)
                        .font(.body)
                        .foregroundStyle(palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let glance {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(spacing: 6) {
                            if let kind = glance.kind {
                                Circle()
                                    .fill(palette.status(kind))
                                    .frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                            }
                            Text(glance.value)
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                        }
                        Text(glance.unit)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.muted)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(palette.muted)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, palette.cardPadding)
            .padding(.vertical, palette.tightSpacing)
            .frame(minHeight: palette.minControl)
            .contentShape(Rectangle())
        }
        .buttonStyle(FieldPressStyle())
        .accessibilityLabel(glance.map { "\(tool.title). \($0.spoken)" } ?? tool.title)
        .accessibilityHint(tool.blurb)
    }
}

struct ToolGroup: Identifiable {
    let title: String
    let tools: [FieldTool]
    var id: String { title }
}

/// The last answer each calculator would show, for the Calc list.
struct ToolGlance {
    var value: String
    var unit: String
    var kind: StatusKind?

    var spoken: String {
        "\(value) \(unit)"
    }

    @MainActor
    static func make(_ tool: FieldTool, model: AppModel) -> ToolGlance? {
        let inputs = model.inputs
        let job = model.job
        switch tool {
        case .spreadRate:
            let report = AsphaltCalculator.spreadRate(
                tons: parseField(inputs.spreadTons),
                distanceFt: parseField(inputs.spreadDistance),
                customTargetLbsSy: inputs.spreadOverride ? parseField(inputs.spreadCustomRate) : nil,
                job: job
            )
            guard let headline = report.headline else { return nil }
            return ToolGlance(value: headline, unit: "lbs/SY", kind: report.spec?.status.kind)
        case .feetLeft:
            let report = AsphaltCalculator.feetLeft(
                tonsOrdered: parseField(inputs.feetOrdered),
                tonsPlaced: model.tonsPlacedToday,
                totalLengthFt: parseField(inputs.feetTotalLength),
                job: job
            )
            guard let headline = report.headline else { return nil }
            return ToolGlance(value: headline, unit: "ft left")
        case .distancePlanner:
            let report = AsphaltCalculator.distancePlan(
                tonsInSilo: parseField(inputs.plannerSilo),
                tonsInTrucks: parseField(inputs.plannerTrucks),
                desiredDistanceFt: parseField(inputs.plannerDesired),
                job: job
            )
            guard let feet = report.availableFeet else { return nil }
            return ToolGlance(value: FieldFormat.groupedRound(feet), unit: "ft available")
        case .tonnage:
            let report = AsphaltCalculator.tonnage(lengthFt: parseField(inputs.tonnageLength), job: job)
            guard let tons = report.tons else { return nil }
            return ToolGlance(value: FieldFormat.fixed(tons, digits: 1), unit: "tons")
        case .tack:
            let report = AsphaltCalculator.tack(lengthFt: parseField(inputs.tackLength), job: job)
            if report.blocked { return ToolGlance(value: "Hold", unit: "do not shoot", kind: .bad) }
            guard let gallons = report.suggestedGallons else { return nil }
            return ToolGlance(value: gallons, unit: "gal")
        case .stickCheck:
            let report = AsphaltCalculator.stick(compactedIn: parseField(inputs.stickTarget))
            guard let headline = report.headline else { return nil }
            return ToolGlance(value: headline, unit: "in loose")
        case .milling:
            return nil
        case .pavingWindow:
            let report = AsphaltCalculator.pavingWindow(job: job)
            guard let check = report.check else { return nil }
            let word: String
            switch check.status {
            case .pass: word = "Open"
            case .warn: word = "Borderline"
            case .fail: word = "Too cold"
            }
            return ToolGlance(value: word, unit: report.headline.map { "\($0) minimum" } ?? "", kind: check.status.kind)
        }
    }
}

struct CalculatorScreen: View {
    let tool: FieldTool

    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette
    @State private var share: SharePayload?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                JobStrip(job: model.job)
                switch tool {
                case .spreadRate:
                    SpreadRateTool()
                case .feetLeft:
                    FeetLeftTool()
                case .distancePlanner:
                    DistancePlannerTool()
                case .tonnage:
                    TonnageTool()
                case .tack:
                    TackTool()
                case .stickCheck:
                    StickCheckTool()
                case .milling:
                    MillingTool()
                case .pavingWindow:
                    PavingWindowTool()
                }
                calculatorActions
            }
            .padding(palette.pagePadding)
        }
        .fieldScroll()
        .navigationTitle(tool.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ScreenModeMenu()
                Button {
                    share = SharePayload(items: SummaryExport.items(for: model.summary(for: tool)))
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2.weight(.bold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Share")
                .accessibilityHint("Sends this calculator as text, a picture, and a PDF.")
            }
        }
        .sheet(item: $share) { payload in
            ActivityShare(items: payload.items)
        }
    }

    @ViewBuilder
    private var calculatorActions: some View {
        if model.canUndo {
            Button("Undo") { model.undoLastChange() }
                .buttonStyle(FieldSecondaryButtonStyle())
                .accessibilityHint("Puts back the last change on this phone.")
        }
        if tool != .pavingWindow {
            Button("Clear") { model.clear(tool) }
                .buttonStyle(FieldSecondaryButtonStyle(destructive: true))
                .accessibilityHint("Clears the numbers typed on this calculator. The job stays.")
        }
    }
}
