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
        VStack(alignment: .leading, spacing: 3) {
            Text(board.callWord)
                .font(.title2.weight(.heavy))
                .foregroundStyle(callTint(board.status))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(board.feetLeftText)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            Text(board.tonsText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(board.jobName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.black.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(board.callWord). \(board.feetLeftText). \(board.tonsText)")
    }

    private func callTint(_ status: String) -> Color {
        switch status {
        case "pass": return Color(red: 0.30, green: 0.90, blue: 0.45)
        case "warn": return Color(red: 1, green: 0.78, blue: 0.15)
        case "fail": return Color(red: 1, green: 0.32, blue: 0.28)
        default: return .white
        }
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
