import XCTest
@testable import PaveRateCore

final class LoadAndSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_592_800)
    private let zone = TimeZone(secondsFromGMT: 0)!

    func testYieldMatchesTheTargetAndFlagsAShortStretch() {
        let job = JobSetup()
        let expected = feetFromTons(18.5, widthFt: 12, rateLbsSy: 165)
        expectClose(expected, 168.1818, digits: 3)
        let onRate = LoadLedger.yield(tons: 18.5, coveredFeet: expected, job: job)
        expectClose(onRate.actualRateLbsSy ?? 0, 165, digits: 1)
        XCTAssertEqual(onRate.spec?.status, .good)

        let heavy = LoadLedger.yield(tons: 18.5, coveredFeet: 50, job: job)
        XCTAssertEqual(heavy.spec?.status, .bad)
        XCTAssertTrue(heavy.spec?.label.hasPrefix("Out of spec") == true)

        let ticketOnly = LoadLedger.yield(tons: 18.5, coveredFeet: nil, job: job)
        XCTAssertNil(ticketOnly.actualRateLbsSy)
        XCTAssertNil(ticketOnly.spec)
        expectClose(ticketOnly.expectedFeet ?? 0, expected, digits: 3)
    }

    func testTonsPlacedIgnoresOrder() {
        let loads = [
            LoadTicket(truck: "412", tons: 18.5, recordedAt: now),
            LoadTicket(truck: "418", tons: 19.25, recordedAt: now)
        ]
        expectClose(LoadLedger.tonsPlaced(loads), 37.75, digits: 2)
        let line = LoadLedger.line(index: 1, load: loads[0], job: JobSetup())
        XCTAssertTrue(line.contains("412"))
        XCTAssertTrue(line.contains("18.50 tons"))
        XCTAssertTrue(line.contains("should reach"))
    }

    func testDailyNoteIsCopyPasteText() {
        var job = JobSetup(siteName: "SR 20")
        job.airTempF = 62
        let weather = WeatherReading(
            airTempF: 62,
            windMph: 8,
            windDirectionDeg: 220,
            groundTempF: 51,
            conditions: "Clear",
            isRaining: false,
            rainNext24hIn: 0,
            hours: [],
            fetchedAt: now.addingTimeInterval(-4 * 60),
            latitude: 33.75,
            longitude: -84.39,
            source: .openMeteo
        )
        let decision = WeatherDecisions.decide(reading: weather, job: job)
        let run = RunMeasure(
            plannedFeet: 1240,
            pavedFeet: 800,
            remainingFeet: 440,
            plannedAreaSqYd: 1653.33,
            pavedAreaSqYd: 1066,
            fraction: 800 / 1240,
            lengthForCalcs: 1240,
            stationPlanned: "12+40",
            stationPaved: "8+00",
            overrun: false
        )
        let load = LoadTicket(truck: "412", tons: 18.5, coveredFeet: 168.1818, recordedAt: now)
        let summary = FieldSummaryText.daily(
            job: job,
            weather: weather,
            decision: decision,
            run: run,
            loads: [load],
            extras: ["Feet left: 420 ft"],
            now: now,
            timeZone: zone
        )
        XCTAssertEqual(summary.title, "SR 20")
        XCTAssertTrue(summary.plainText.contains("Nov 13, 2026"))
        XCTAssertTrue(summary.plainText.contains("12 ft wide"))
        XCTAssertTrue(summary.plainText.contains("OK to pave"))
        XCTAssertTrue(summary.plainText.contains("Open-Meteo, 4 min ago"))
        XCTAssertTrue(summary.plainText.contains("not an IR reading"))
        XCTAssertTrue(summary.plainText.contains("12+40"))
        XCTAssertTrue(summary.plainText.contains("In spec"))
        XCTAssertTrue(summary.plainText.contains("Feet left: 420 ft"))
        XCTAssertTrue(summary.plainText.contains("Check the ticket"))
        XCTAssertFalse(summary.plainText.contains("token"))
    }

    func testShortNoteDropsEmptyDetails() {
        let summary = FieldSummaryText.compose(
            title: "Tack",
            job: JobSetup(),
            details: ["  ", "Mid rate: 120 gal"],
            now: now,
            timeZone: zone
        )
        XCTAssertTrue(summary.plainText.contains("Tack"))
        XCTAssertTrue(summary.plainText.contains("Mid rate: 120 gal"))
        XCTAssertFalse(summary.plainText.contains("  \n"))
    }
}
