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
    }
}

enum ConsoleActivity {
    private static var suppressed = false

    static func sync(_ board: FieldBoard, enabled: Bool) {
        if !enabled {
            suppressed = false
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
            guard !suppressed else { return }
            do {
                _ = try Activity.request(
                    attributes: PaveActivityAttributes(jobName: board.jobName),
                    content: content,
                    pushType: nil
                )
            } catch {
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
