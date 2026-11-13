import XCTest
@testable import PaveRateCore

final class ConsoleRoundTests: XCTestCase {
    func testPlantCall() {
        let comfortable = PlantCallCheck.evaluate(orderedTons: 200, placedTons: 40, thresholdTons: 18.5)
        XCTAssertFalse(comfortable.shouldCall)

        let low = PlantCallCheck.evaluate(orderedTons: 100, placedTons: 90, thresholdTons: 18.5)
        XCTAssertTrue(low.shouldCall)
        XCTAssertTrue(low.message.contains("Call the plant"))

        let over = PlantCallCheck.evaluate(orderedTons: 80, placedTons: 90, thresholdTons: 18.5)
        XCTAssertTrue(over.shouldCall)
        XCTAssertTrue(over.message.contains("over the order"))

        let unknown = PlantCallCheck.evaluate(orderedTons: nil, placedTons: 10, thresholdTons: 18.5)
        XCTAssertFalse(unknown.shouldCall)
    }

    func testDayIsKeptOnlyWhenSomethingWasRecorded() {
        XCTAssertFalse(DayHistory.shouldKeep(
            loads: [],
            pavedPoints: [],
            photoNotes: [],
            tonsOrdered: nil,
            weather: nil,
            dayNote: "  "
        ))
        XCTAssertTrue(DayHistory.shouldKeep(
            loads: [LoadTicket(truck: "12", tons: 18)],
            pavedPoints: [],
            photoNotes: [],
            tonsOrdered: nil,
            weather: nil,
            dayNote: ""
        ))
        XCTAssertTrue(DayHistory.shouldKeep(
            loads: [],
            pavedPoints: [],
            photoNotes: [],
            tonsOrdered: nil,
            weather: nil,
            dayNote: "Joint at the driveway"
        ))
    }

    func testPhotoLineCarriesStation() {
        let note = PhotoNote(
            caption: "Segregation",
            stationFeet: 1250,
            latitude: 33.749,
            longitude: -84.388,
            imageFilename: "a.jpg"
        )
        let line = note.line(index: 1)
        XCTAssertTrue(line.contains("Segregation"))
        XCTAssertTrue(line.contains("12+50"))
        XCTAssertTrue(line.contains("33.74900"))
    }

    func testBoardRoundTripAndText() {
        let now = Date(timeIntervalSince1970: 1_794_592_800)
        let board = FieldBoard.make(
            jobName: "SR 20",
            feetLeft: 420,
            tonsOrdered: 100,
            tonsPlaced: 40,
            headline: "OK to pave",
            status: .pass,
            now: now
        )
        XCTAssertEqual(board.feetLeftText, "420 ft left")
        XCTAssertEqual(board.tonsText, "60.0 tons left")
        XCTAssertEqual(board.status, "pass")
        let defaults = UserDefaults(suiteName: "console-round-tests")!
        defaults.removePersistentDomain(forName: "console-round-tests")
        FieldBoardStore.write(board, defaults: defaults)
        let read = FieldBoardStore.read(defaults: defaults)
        XCTAssertEqual(read, board)
        XCTAssertEqual(FieldBoardStore.appGroupID, "group.com.paverate.ios")
    }

    func testWindThresholdIsConfigurable() {
        var reading = WeatherReading(
            airTempF: 70,
            windMph: 12,
            conditions: "Clear",
            isRaining: false,
            rainNext24hIn: 0,
            hours: [],
            fetchedAt: Date(),
            latitude: 33,
            longitude: -84,
            source: .openMeteo
        )
        let quiet = WeatherDecisions.decide(reading: reading, job: JobSetup(), windNoteMph: 15, strongWindMph: 25)
        XCTAssertNil(quiet.windNote)
        XCTAssertEqual(quiet.status, .pass)

        reading.windMph = 16
        let noted = WeatherDecisions.decide(reading: reading, job: JobSetup(), windNoteMph: 10, strongWindMph: 25)
        XCTAssertNotNil(noted.windNote)
        XCTAssertEqual(noted.status, .warn)
        XCTAssertTrue(noted.windNote?.contains("not a GDOT cutoff") == true)
    }

    func testOldLoadTicketDecodesWithoutAPhoto() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","truck":"412","tons":18.5,"coveredFeet":100,"recordedAt":1794592800}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let ticket = try decoder.decode(LoadTicket.self, from: json)
        XCTAssertEqual(ticket.truck, "412")
        XCTAssertNil(ticket.ticketPhotoFilename)
        expectClose(ticket.tons, 18.5, digits: 2)
    }

    func testPeopleLineAndStationHeadline() {
        var settings = FieldSettings()
        XCTAssertNil(settings.peopleLine)
        settings.foremanName = "Alex"
        settings.crewName = "2"
        XCTAssertEqual(settings.peopleLine, "Foreman Alex · Crew 2")
        settings.lengthDisplay = .stations
        XCTAssertEqual(settings.lengthHeadline(feet: 1250), "12+50")
        settings.lengthDisplay = .feet
        XCTAssertEqual(settings.lengthHeadline(feet: 1250), "1,250 ft")
    }

    func testSummaryNamesTheForemanAndThePhoto() {
        let note = PhotoNote(caption: "Joint", stationFeet: 400, imageFilename: "j.jpg")
        let summary = FieldSummaryText.daily(
            job: JobSetup(siteName: "SR 20"),
            weather: nil,
            decision: nil,
            run: nil,
            loads: [],
            photoNotes: [note],
            now: Date(timeIntervalSince1970: 1_794_592_800),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            people: "Foreman Alex"
        )
        XCTAssertTrue(summary.plainText.contains("Foreman Alex"))
        XCTAssertTrue(summary.plainText.contains("Joint"))
        XCTAssertTrue(summary.plainText.contains("4+00"))
    }
}
