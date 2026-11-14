import SwiftUI
import PaveRateCore

struct ToolListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.fieldPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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
                        .padding(18)
                        .frame(minHeight: 84)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(palette.border, lineWidth: palette.borderWidth)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
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
            VStack(alignment: .leading, spacing: 22) {
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
            }
            .padding(20)
        }
        .navigationTitle(tool.title)
        .background(palette.background.ignoresSafeArea())
        .fieldKeyboardDone()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if model.canUndo {
                    Button("Undo") { model.undoLastChange() }
                        .font(.title3.weight(.bold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share") {
                    share = SharePayload(items: SummaryExport.items(for: model.summary(for: tool)))
                }
                .font(.title3.weight(.bold))
            }
            if tool != .pavingWindow {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { model.clear(tool) }
                        .font(.title3.weight(.bold))
                }
            }
        }
        .sheet(item: $share) { payload in
            ActivityShare(items: payload.items)
        }
    }
}
