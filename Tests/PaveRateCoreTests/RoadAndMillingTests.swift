import XCTest
@testable import PaveRateCore

final class RoadAndMillingTests: XCTestCase {
    func testTrimStopsAtTheRequestedFeet() {
        let line = [
            GeoPoint(latitude: 33.7490, longitude: -84.3880),
            GeoPoint(latitude: 33.7580, longitude: -84.3880)
        ]
        let full = GeoMeasure.polylineFeet(line)
        let trimmed = RoadFollow.trim(line, toFeet: 400)
        expectClose(GeoMeasure.polylineFeet(trimmed), 400, digits: 0)
        XCTAssertLessThan(GeoMeasure.polylineFeet(trimmed), full)
        let past = RoadFollow.trim(line, toFeet: full + 500)
        expectClose(GeoMeasure.polylineFeet(past), full, digits: 0)
    }

    func testTraceFollowsTheSameNameAndOffersTheCrossStreet() {
        let south = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let mid = GeoPoint(latitude: 33.7530, longitude: -84.3880)
        let north = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        let east = GeoPoint(latitude: 33.7580, longitude: -84.3800)
        let pieces = [
            RoadPiece(name: "SR 20", points: [south, mid]),
            RoadPiece(name: "SR 20", points: [mid, north]),
            RoadPiece(name: "Main", points: [north, east])
        ]
        let start = GeoPoint(latitude: 33.7500, longitude: -84.3880)
        let trace = RoadFollow.trace(pieces: pieces, from: start)
        XCTAssertEqual(trace?.roadName, "SR 20")
        XCTAssertEqual(trace?.directions.count, 2)
        let northbound = trace?.directions.max { $0.lengthFeet < $1.lengthFeet }
        XCTAssertEqual(northbound?.heading, "N")
        XCTAssertEqual(northbound?.forks.map(\.name), ["Main"])
        let southbound = trace?.directions.min { $0.lengthFeet < $1.lengthFeet }
        XCTAssertEqual(southbound?.heading, "S")
        XCTAssertTrue(southbound?.forks.isEmpty == true)
    }

    func testSameNameForkStopsForAChoice() {
        let south = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let mid = GeoPoint(latitude: 33.7530, longitude: -84.3880)
        let north = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        let northeast = GeoPoint(latitude: 33.7580, longitude: -84.3800)
        let pieces = [
            RoadPiece(name: "SR 20", points: [south, mid]),
            RoadPiece(name: "SR 20", points: [mid, north]),
            RoadPiece(name: "SR 20", points: [mid, northeast])
        ]
        let trace = RoadFollow.trace(pieces: pieces, from: GeoPoint(latitude: 33.7500, longitude: -84.3880))
        let northbound = trace?.directions.first { $0.heading == "N" }
        XCTAssertEqual(northbound?.forks.count, 2)
        XCTAssertTrue(northbound?.forks.allSatisfy { $0.name == "SR 20" } == true)
    }

    func testAPointOffTheRoadDoesNotSnap() {
        let pieces = [
            RoadPiece(name: "SR 20", points: [
                GeoPoint(latitude: 33.749, longitude: -84.388),
                GeoPoint(latitude: 33.752, longitude: -84.388)
            ])
        ]
        let far = GeoPoint(latitude: 33.749, longitude: -84.370)
        XCTAssertNil(RoadFollow.trace(pieces: pieces, from: far))
    }

    func testMileMarkersFallOnWholeMiles() {
        let line = [
            GeoPoint(latitude: 33.7490, longitude: -84.3880),
            GeoPoint(latitude: 33.7580, longitude: -84.3880)
        ]
        let markers = RoadFollow.mileMarkers(points: line, beginMile: 12.2, endMile: 14.6)
        XCTAssertEqual(markers.map(\.label), ["MP 13", "MP 14"])
        let length = GeoMeasure.polylineFeet(line)
        let firstFeet = GeoMeasure.haversineFeet(line[0], markers[0].point)
        let fraction = (13 - 12.2) / (14.6 - 12.2)
        expectClose(firstFeet, length * fraction, digits: 0)
    }

    func testMillingQuantity() {
        let result = MillingCalculator.calculate(
            lengthFt: 900,
            widthFt: 12,
            depthIn: 2,
            densityTonsPerCubicYard: 2,
            truckTons: 18.5
        )
        XCTAssertEqual(result?.squareYards, 1200)
        expectClose(result?.cubicYards ?? 0, 900 * 2 / 27, digits: 3)
        expectClose(result?.tons ?? 0, (900 * 2 / 27) * 2, digits: 3)
        expectClose(result?.truckloads ?? 0, ((900 * 2 / 27) * 2) / 18.5, digits: 3)
        XCTAssertNil(MillingCalculator.calculate(
            lengthFt: 0, widthFt: 12, depthIn: 2, densityTonsPerCubicYard: 2, truckTons: 18
        ))
    }
}
