import ActivityKit
import Foundation
import WidgetKit
import PaveRateCore

enum FieldBoardPublisher {
    static func publish(_ board: FieldBoard, console: Bool) {
        if let shared = FieldBoardStore.sharedDefaults() {
            FieldBoardStore.write(board, defaults: shared)
        }
        FieldBoardStore.write(board, defaults: .standard)
        WidgetCenter.shared.reloadAllTimelines()
        ConsoleActivity.sync(board, enabled: console)
        WatchBridge.shared.send(board)
    }
}

enum ConsoleActivity {
    private static var suppressed = false
    private static var requesting = false

    static func sync(_ board: FieldBoard, enabled: Bool) {
        if !enabled {
            suppressed = false
            requesting = false
            endAll()
            return
        }
        let state = PaveActivityAttributes.ContentState(
            feetLeftText: board.feetLeftText,
            tonsText: board.tonsText,
            headline: board.headline,
            status: board.status
        )
        let content = ActivityContent(state: state, staleDate: nil)
        let existing = Activity<PaveActivityAttributes>.activities
        if existing.isEmpty {
            guard !suppressed, !requesting else { return }
            requesting = true
            do {
                _ = try Activity.request(
                    attributes: PaveActivityAttributes(jobName: board.jobName),
                    content: content,
                    pushType: nil
                )
                requesting = false
            } catch {
                requesting = false
                suppressed = true
            }
            return
        }
        for activity in existing {
            Task { await activity.update(content) }
        }
    }

    private static func endAll() {
        for activity in Activity<PaveActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
