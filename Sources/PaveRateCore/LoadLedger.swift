import Foundation

public struct LoadTicket: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var truck: String
    public var tons: Double
    /// Feet this load covered. Empty when the ticket is in and the length is not.
    public var coveredFeet: Double?
    public var recordedAt: Date
    /// JPEG stored on the phone. Older saves omit this key.
    public var ticketPhotoFilename: String?

    public init(
        id: UUID = UUID(),
        truck: String,
        tons: Double,
        coveredFeet: Double? = nil,
        recordedAt: Date = Date(),
        ticketPhotoFilename: String? = nil
    ) {
        self.id = id
        self.truck = truck
        self.tons = tons
        self.coveredFeet = coveredFeet
        self.recordedAt = recordedAt
        self.ticketPhotoFilename = ticketPhotoFilename
    }

    private enum CodingKeys: String, CodingKey {
        case id, truck, tons, coveredFeet, recordedAt, ticketPhotoFilename
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        truck = try container.decode(String.self, forKey: .truck)
        tons = try container.decode(Double.self, forKey: .tons)
        coveredFeet = try container.decodeIfPresent(Double.self, forKey: .coveredFeet)
        recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        ticketPhotoFilename = try container.decodeIfPresent(String.self, forKey: .ticketPhotoFilename)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(truck, forKey: .truck)
        try container.encode(tons, forKey: .tons)
        try container.encodeIfPresent(coveredFeet, forKey: .coveredFeet)
        try container.encode(recordedAt, forKey: .recordedAt)
        try container.encodeIfPresent(ticketPhotoFilename, forKey: .ticketPhotoFilename)
    }
}

public struct LoadYield: Equatable, Sendable {
    public var tons: Double
    public var expectedFeet: Double?
    public var actualRateLbsSy: Double?
    public var spec: SpreadSpecCheck?

    public init(
        tons: Double,
        expectedFeet: Double?,
        actualRateLbsSy: Double?,
        spec: SpreadSpecCheck?
    ) {
        self.tons = tons
        self.expectedFeet = expectedFeet
        self.actualRateLbsSy = actualRateLbsSy
        self.spec = spec
    }
}

public enum LoadLedger {
    public static func tonsPlaced(_ loads: [LoadTicket]) -> Double {
        loads.reduce(0) { $0 + $1.tons }
    }

    /// How far this ticket should reach, and the Table 12 call if a length was entered.
    ///
    /// Hopper retention is not removed here. That subtraction belongs to the
    /// first-pass spread check, once per start, not once per truck.
    public static func yield(tons: Double, coveredFeet: Double?, job: JobSetup) -> LoadYield {
        let target = job.targetRateLbsSy
        let expected: Double?
        if target > 0, job.widthFt > 0, tons > 0 {
            expected = feetFromTons(tons, widthFt: job.widthFt, rateLbsSy: target)
        } else {
            expected = nil
        }
        let actual: Double?
        if let coveredFeet, coveredFeet > 0, job.widthFt > 0, tons > 0 {
            actual = actualSpreadRate(tons: tons, distanceFt: coveredFeet, widthFt: job.widthFt)
        } else {
            actual = nil
        }
        let spec = spreadSpecCheck(
            placedLbsSy: actual,
            targetLbsSy: target > 0 ? target : nil,
            courseId: job.courseTypeId
        )
        return LoadYield(tons: tons, expectedFeet: expected, actualRateLbsSy: actual, spec: spec)
    }

    public static func line(index: Int, load: LoadTicket, job: JobSetup) -> String {
        let yield = yield(tons: load.tons, coveredFeet: load.coveredFeet, job: job)
        var parts = ["\(index). \(load.truck.isEmpty ? "Truck" : load.truck)"]
        parts.append("\(FieldFormat.fixed(load.tons, digits: 2)) tons")
        if let covered = load.coveredFeet, covered > 0 {
            parts.append("\(FieldFormat.groupedRound(covered)) ft")
        }
        if let rate = yield.actualRateLbsSy {
            parts.append("\(FieldFormat.groupedRound(rate)) lbs/SY")
        } else if let expected = yield.expectedFeet {
            parts.append("should reach \(FieldFormat.groupedRound(expected)) ft")
        }
        if let spec = yield.spec {
            parts.append(spec.label)
        }
        return parts.joined(separator: " · ")
    }
}
