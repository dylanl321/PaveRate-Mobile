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
                .containerBackground(Color.white, for: .widget)
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
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(board.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(callColor(board.status))
                Text(board.feetLeftText)
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(board.tonsText)
                    .font(.body.weight(.semibold))
                Text(board.jobName)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

struct PaveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.headline)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(callColor(context.state.status))
                Text(context.state.feetLeftText)
                    .font(.title.weight(.bold))
                Text(context.state.tonsText)
                    .font(.title3.weight(.semibold))
                Text(context.attributes.jobName)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .activityBackgroundTint(Color.white)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.feetLeftText).font(.headline.weight(.bold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.tonsText).font(.headline.weight(.bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline)
                }
            } compactLeading: {
                Text(shortCall(status: context.state.status))
            } compactTrailing: {
                Text(context.state.feetLeftText).lineLimit(1)
            } minimal: {
                Text(shortCall(status: context.state.status))
            }
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

private func callColor(_ status: String) -> Color {
    switch status {
    case "pass": return Color(red: 0, green: 0.35, blue: 0.12)
    case "warn": return Color(red: 0.55, green: 0.22, blue: 0)
    case "fail": return Color(red: 0.7, green: 0, blue: 0)
    default: return .black
    }
}
