import SwiftUI
import PaveRateCore

struct ToolListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: palette.stackSpacing) {
                JobStrip(job: model.job)
                Text("Shared setup is on the Job tab. Every calculator uses it.")
                    .font(.body)
                    .foregroundStyle(palette.muted)

                Text("Asphalt")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.text)
                    .padding(.top, 8)

                ForEach(FieldTool.allCases) { tool in
                    NavigationLink {
                        CalculatorScreen(tool: tool)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.title)
                                .font(.title2.weight(.bold))
                            Text(tool.blurb)
                                .font(.title3)
                        }
                        .foregroundStyle(palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(palette.cardPadding)
                        .frame(minHeight: 84)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: palette.cornerRadius)
                                .stroke(palette.border, lineWidth: palette.borderWidth)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(palette.pagePadding)
        }
        .fieldScroll()
        .navigationTitle("PaveRate")
        .background(palette.background.ignoresSafeArea())
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
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
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
        Button("Share") {
            share = SharePayload(items: SummaryExport.items(for: model.summary(for: tool)))
        }
        .buttonStyle(FieldSecondaryButtonStyle())
        .accessibilityHint("Sends this calculator as text, a picture, and a PDF.")
        if tool != .pavingWindow {
            Button("Clear") { model.clear(tool) }
                .buttonStyle(FieldSecondaryButtonStyle(destructive: true))
                .accessibilityHint("Clears the numbers typed on this calculator. The job stays.")
        }
    }
}
