import Foundation

/// The numbers on the Lock Screen and the Home Screen widget.
public struct FieldBoard: Codable, Equatable, Sendable {
    public var jobName: String
    public var feetLeft: Double?
    public var tonsRemaining: Double?
    public var tonsPlaced: Double
    public var tonsOrdered: Double?
    public var headline: String
    /// `pass`, `warn`, `fail`, or `none`.
    public var status: String
    public var updatedAt: Date

    public init(
        jobName: String,
        feetLeft: Double?,
        tonsRemaining: Double?,
        tonsPlaced: Double,
        tonsOrdered: Double?,
        headline: String,
        status: String,
        updatedAt: Date
    ) {
        self.jobName = jobName
        self.feetLeft = feetLeft
        self.tonsRemaining = tonsRemaining
        self.tonsPlaced = tonsPlaced
        self.tonsOrdered = tonsOrdered
        self.headline = headline
        self.status = status
        self.updatedAt = updatedAt
    }

    public var feetLeftText: String {
        guard let feetLeft else { return "Feet —" }
        return "\(FieldFormat.groupedRound(feetLeft)) ft left"
    }

    public var tonsText: String {
        if let tonsRemaining {
            return "\(FieldFormat.fixed(max(tonsRemaining, 0), digits: 1)) tons left"
        }
        return "\(FieldFormat.fixed(tonsPlaced, digits: 1)) tons placed"
    }

    public static func make(
        jobName: String,
        feetLeft: Double?,
        tonsOrdered: Double?,
        tonsPlaced: Double,
        headline: String,
        status: PlacementStatus?,
        now: Date
    ) -> FieldBoard {
        let remaining = tonsOrdered.map { $0 - tonsPlaced }
        return FieldBoard(
            jobName: jobName.isEmpty ? "PaveRate" : jobName,
            feetLeft: feetLeft,
            tonsRemaining: remaining,
            tonsPlaced: tonsPlaced,
            tonsOrdered: tonsOrdered,
            headline: headline,
            status: status?.rawValue ?? "none",
            updatedAt: now
        )
    }

    public static let empty = FieldBoard(
        jobName: "PaveRate",
        feetLeft: nil,
        tonsRemaining: nil,
        tonsPlaced: 0,
        tonsOrdered: nil,
        headline: "Open PaveRate",
        status: "none",
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

public enum FieldBoardStore {
    public static let appGroupID = "group.com.paverate.ios"
    public static let key = "paverate.fieldboard"

    public static func write(_ board: FieldBoard, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(board) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read(defaults: UserDefaults) -> FieldBoard? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FieldBoard.self, from: data)
    }

    public static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

#if canImport(ActivityKit)
import ActivityKit

/// Shared by the app and the widget extension. Linux tests skip this block.
public struct PaveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var feetLeftText: String
        public var tonsText: String
        public var headline: String
        public var status: String

        public init(feetLeftText: String, tonsText: String, headline: String, status: String) {
            self.feetLeftText = feetLeftText
            self.tonsText = tonsText
            self.headline = headline
            self.status = status
        }
    }

    public var jobName: String

    public init(jobName: String) {
        self.jobName = jobName
    }
}
#endif
