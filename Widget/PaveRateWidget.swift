import ActivityKit
import SwiftUI
import WidgetKit
import PaveRateCore

@main
struct PaveWidgets: WidgetBundle {
    var body: some Widget {
        FeetLeftWidget()
        PaveLiveActivity()
    }
}

struct FeetLeftWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FeetLeft", provider: BoardProvider()) { entry in
            BoardFace(board: entry.board)
                .containerBackground(BoardInk.background, for: .widget)
        }
        .configurationDisplayName("Feet left")
        .description("Feet left, tons remaining, and the go or hold call.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct BoardEntry: TimelineEntry {
    var date: Date
    var board: FieldBoard
}

struct BoardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        BoardEntry(date: Date(), board: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(BoardEntry(date: Date(), board: current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        let entry = BoardEntry(date: Date(), board: current())
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func current() -> FieldBoard {
        if let shared = FieldBoardStore.sharedDefaults(), let board = FieldBoardStore.read(defaults: shared) {
            return board
        }
        return .empty
    }
}

struct BoardFace: View {
    var board: FieldBoard
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(board.feetLeftText) · \(shortCall(board))")
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(BoardInk.number)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(board.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(callColor(board.status))
                Text(board.feetLeftText)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(BoardInk.number)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(board.tonsText)
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(BoardInk.text)
                Text(board.jobName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BoardInk.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

struct PaveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(callColor(context.state.status))
                Text(context.state.feetLeftText)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BoardInk.number)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(context.state.tonsText)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BoardInk.text)
                    .lineLimit(1)
                Text(context.attributes.jobName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BoardInk.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(BoardInk.background)
            .activityBackgroundTint(BoardInk.background)
            .activitySystemActionForegroundColor(BoardInk.text)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.feetLeftText)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(BoardInk.number)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.tonsText)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(BoardInk.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.jobName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BoardInk.text)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(callColor(context.state.status))
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(shortCall(status: context.state.status))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(callColor(context.state.status))
            } compactTrailing: {
                Text(context.state.feetLeftText)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(BoardInk.number)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                Text(shortCall(status: context.state.status))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(callColor(context.state.status))
            }
            .keylineTint(callColor(context.state.status))
        }
    }
}

private func shortCall(_ board: FieldBoard) -> String {
    shortCall(status: board.status)
}

private func shortCall(status: String) -> String {
    switch status {
    case "pass": return "Go"
    case "warn": return "Watch"
    case "fail": return "Hold"
    default: return "—"
    }
}

/// Opaque near-black board. Lock Screen and Home Screen text is painted on this, never on the system white.
private enum BoardInk {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.08)
    static let number = Color(red: 1, green: 0.86, blue: 0.2)
    static let text = Color.white
}

private func callColor(_ status: String) -> Color {
    switch status {
    case "pass": return Color(red: 0.30, green: 0.90, blue: 0.45)
    case "warn": return Color(red: 1, green: 0.78, blue: 0.15)
    case "fail": return Color(red: 1, green: 0.32, blue: 0.28)
    default: return BoardInk.text
    }
}
