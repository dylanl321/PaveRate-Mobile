import Foundation
import WatchConnectivity
import PaveRateCore

/// Sends the glance numbers to the watch. No App Group. A missing watch is ignored.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private var latest: FieldBoard?
    private var started = false

    func start() {
        guard WCSession.isSupported(), !started else { return }
        started = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ board: FieldBoard) {
        latest = board
        push()
    }

    private func push() {
        guard WCSession.isSupported(), let latest else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = FieldBoardCoding.data(from: latest) else { return }
        try? session.updateApplicationContext(["board": data])
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        push()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
