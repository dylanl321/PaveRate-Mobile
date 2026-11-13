import XCTest
@testable import PaveRateCore

final class GeoMeasureTests: XCTestCase {
    func testHaversineNorthAndEast() {
        let start = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let north = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        let east = GeoPoint(latitude: 33.7490, longitude: -84.3780)
        expectClose(GeoMeasure.haversineMeters(start, north), 1000.75, digits: 1)
        expectClose(GeoMeasure.haversineFeet(start, north), 3283.31, digits: 1)
        expectClose(GeoMeasure.haversineMeters(start, east), 924.56, digits: 1)
        XCTAssertEqual(GeoMeasure.haversineMeters(start, start), 0)
        XCTAssertEqual(GeoMeasure.polylineFeet([start]), 0)
        XCTAssertEqual(GeoMeasure.polylineFeet([]), 0)
    }

    func testPolylineSumsSegments() {
        let start = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let mid = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        let end = GeoPoint(latitude: 33.7580, longitude: -84.3780)
        let combined = GeoMeasure.polylineFeet([start, mid, end])
        let parts = GeoMeasure.haversineFeet(start, mid) + GeoMeasure.haversineFeet(mid, end)
        expectClose(combined, parts, digits: 4)
    }

    func testAreaAndStation() {
        expectClose(GeoMeasure.areaSquareYards(lengthFt: 900, widthFt: 12), 1200, digits: 4)
        XCTAssertEqual(GeoMeasure.areaSquareYards(lengthFt: 100, widthFt: 0), 0)
        XCTAssertEqual(GeoMeasure.stationLabel(feet: 1250), "12+50")
        XCTAssertEqual(GeoMeasure.stationLabel(feet: 100), "1+00")
        XCTAssertEqual(GeoMeasure.stationLabel(feet: 0), "0+00")
        XCTAssertEqual(GeoMeasure.stationLabel(feet: 50.4), "0+50")
        expectClose(GeoMeasure.miles(feet: 5280), 1, digits: 4)
    }

    func testCompass() {
        XCTAssertEqual(GeoMeasure.compassLabel(degrees: 0), "N")
        XCTAssertEqual(GeoMeasure.compassLabel(degrees: 45), "NE")
        XCTAssertEqual(GeoMeasure.compassLabel(degrees: 220), "SW")
        XCTAssertEqual(GeoMeasure.compassLabel(degrees: 360), "N")
        XCTAssertEqual(GeoMeasure.compassLabel(degrees: -45), "NW")
    }

    func testPointAlongIsMidpointOfANorthSouthSegment() {
        let start = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let end = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        let length = GeoMeasure.haversineFeet(start, end)
        let mid = GeoMeasure.pointAlong(points: [start, end], feet: length / 2)
        expectClose(mid?.latitude ?? 0, 33.7535, digits: 3)
        expectClose(mid?.longitude ?? 0, -84.3880, digits: 4)
        let prefix = GeoMeasure.prefix(points: [start, end], feet: length / 2)
        XCTAssertEqual(prefix.count, 2)
        XCTAssertEqual(prefix.first, start)
        XCTAssertEqual(GeoMeasure.prefix(points: [start, end], feet: length + 10).last, end)
        XCTAssertEqual(GeoMeasure.pointAlong(points: [], feet: 10), nil)
    }

    func testTrackFilter() {
        let start = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let far = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        XCTAssertEqual(
            GeoMeasure.appendTrackPoint([], next: start, accuracyMeters: 40),
            []
        )
        XCTAssertEqual(
            GeoMeasure.appendTrackPoint([], next: start, accuracyMeters: -1),
            []
        )
        XCTAssertEqual(
            GeoMeasure.appendTrackPoint([], next: start, accuracyMeters: 8),
            [start]
        )
        let close = GeoPoint(latitude: 33.74901, longitude: -84.3880)
        XCTAssertEqual(
            GeoMeasure.appendTrackPoint([start], next: close, accuracyMeters: 5),
            [start]
        )
        XCTAssertEqual(
            GeoMeasure.appendTrackPoint([start], next: far, accuracyMeters: 5),
            [start, far]
        )
        let capped = GeoMeasure.appendTrackPoint(
            [start],
            next: far,
            accuracyMeters: 5,
            maxPoints: 1
        )
        XCTAssertEqual(capped, [start])
    }

    func testRunMeasureFeedsPlanLengthAndFlagsOverrun() {
        let start = GeoPoint(latitude: 33.7490, longitude: -84.3880)
        let end = GeoPoint(latitude: 33.7580, longitude: -84.3880)
        let plan = GeoMeasure.measure(planned: [start, end], paved: [], widthFt: 12)
        expectClose(plan.lengthForCalcs, plan.plannedFeet, digits: 4)
        expectClose(plan.plannedAreaSqYd, plan.plannedFeet * 12 / 9, digits: 2)
        XCTAssertFalse(plan.overrun)
        XCTAssertEqual(plan.fraction, 0)

        let trackOnly = GeoMeasure.measure(planned: [], paved: [start, end], widthFt: 12)
        expectClose(trackOnly.lengthForCalcs, trackOnly.pavedFeet, digits: 4)
        XCTAssertEqual(trackOnly.remainingFeet, 0)

        let overrun = GeoMeasure.measure(
            planned: [start, end],
            paved: [start, end, GeoPoint(latitude: 33.7600, longitude: -84.3880)],
            widthFt: 12
        )
        XCTAssertTrue(overrun.overrun)
        XCTAssertGreaterThan(overrun.fraction, 1)
    }
}
