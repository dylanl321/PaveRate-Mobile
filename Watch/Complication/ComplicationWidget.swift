import SwiftUI
import WatchConnectivity
import WidgetKit
import PaveRateCore

@main
struct PaveComplications: WidgetBundle {
    var body: some Widget {
        PaveComplication()
    }
}

struct PaveComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PaveGlance", provider: ComplicationProvider()) { entry in
            ComplicationFace(board: entry.board)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("PaveRate")
        .description("Go or hold, feet left, and tons left.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct ComplicationEntry: TimelineEntry {
    var date: Date
    var board: FieldBoard
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), board: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date(), board: current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), board: current())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    /// The phone pushes this context. No App Group.
    private func current() -> FieldBoard {
        guard WCSession.isSupported() else { return .empty }
        let session = WCSession.default
        if let board = FieldBoardCoding.board(from: session.receivedApplicationContext["board"] as? Data) {
            return board
        }
        return .empty
    }
}

struct ComplicationFace: View {
    var board: FieldBoard
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryCorner:
            Text(board.callWord)
                .font(.headline.weight(.bold))
        case .accessoryInline:
            Text("\(board.feetLeftText) · \(board.callWord)")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(board.callWord).font(.headline.weight(.bold))
                Text(board.feetLeftText).font(.caption.weight(.semibold)).lineLimit(1)
                Text(board.tonsText).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
