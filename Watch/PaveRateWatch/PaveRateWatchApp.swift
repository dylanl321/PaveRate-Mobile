import SwiftUI
import WatchConnectivity
import PaveRateCore

@main
struct PaveRateWatchApp: App {
    @StateObject private var session = WatchSession()

    var body: some Scene {
        WindowGroup {
            WatchGlance(board: session.board)
        }
    }
}

struct WatchGlance: View {
    var board: FieldBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(board.callWord)
                .font(.title3.weight(.bold))
            Text(board.feetLeftText)
                .font(.headline.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Text(board.tonsText)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            Text(board.jobName)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(board.callWord). \(board.feetLeftText). \(board.tonsText)")
    }
}

final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    @Published var board: FieldBoard = .empty

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        if let decoded = FieldBoardCoding.board(from: session.receivedApplicationContext["board"] as? Data) {
            board = decoded
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ context: [String: Any]) {
        guard let board = FieldBoardCoding.board(from: context["board"] as? Data) else { return }
        DispatchQueue.main.async {
            self.board = board
        }
    }
}
