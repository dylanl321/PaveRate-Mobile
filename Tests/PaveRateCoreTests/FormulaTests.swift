import XCTest
@testable import PaveRateCore

/// Mirrors `src/lib/calc/__tests__/formulas.test.ts` for the asphalt functions.
final class FormulaTests: XCTestCase {
    func testSquareYards() {
        expectClose(squareYards(100, 18), 200, digits: 4)
        expectClose(squareYards(1320, 12), 1760, digits: 4)
        XCTAssertEqual(squareYards(0, 18), 0)
        XCTAssertEqual(squareYards(100, 0), 0)
        expectClose(squareYards(9, 9), 9, digits: 4)
    }

    func testSpreadRatePlaced() {
        expectClose(
            spreadRatePlaced(tons: 10, lengthFt: 100, widthFt: 18, firstPass: false),
            100,
            digits: 2
        )
        XCTAssertEqual(spreadRatePlaced(tons: 10, lengthFt: 0, widthFt: 18), 0)
        expectClose(
            spreadRatePlaced(tons: 100, lengthFt: 100, widthFt: 18, machineId: "paver", firstPass: true),
            860,
            digits: 1
        )
        expectClose(
            spreadRatePlaced(tons: 100, lengthFt: 100, widthFt: 18, machineId: "none", firstPass: true),
            1000,
            digits: 1
        )
        expectClose(
            spreadRatePlaced(tons: 1000, lengthFt: 1000, widthFt: 90, firstPass: false),
            200,
            digits: 2
        )
        // Shuttle buggy retains 24 tons. Same shape as the paver case in the web tests.
        expectClose(
            spreadRatePlaced(tons: 100, lengthFt: 100, widthFt: 18, machineId: "shuttle", firstPass: true),
            760,
            digits: 1
        )
        // An unknown machine id falls through to the first machine (paver, 14 tons).
        expectClose(
            spreadRatePlaced(tons: 100, lengthFt: 100, widthFt: 18, machineId: "missing", firstPass: true),
            860,
            digits: 1
        )
        // Omitted machine id is `none`, so first pass does not subtract hopper tons.
        expectClose(
            spreadRatePlaced(tons: 100, lengthFt: 100, widthFt: 18, firstPass: true),
            1000,
            digits: 1
        )
    }

    func testSpreadRateFromThickness() {
        expectClose(spreadRateFromThickness(1.5), 165, digits: 4)
        expectClose(spreadRateFromThickness(2), 220, digits: 4)
        expectClose(spreadRateFromThickness(3), 330, digits: 4)
        XCTAssertEqual(spreadRateFromThickness(0), 0)
    }

    func testFeetFromTons() {
        expectClose(feetFromTons(10, widthFt: 12, rateLbsSy: 165), 90.91, digits: 1)
        XCTAssertEqual(feetFromTons(10, widthFt: 0, rateLbsSy: 165), 0)
        XCTAssertEqual(feetFromTons(10, widthFt: 12, rateLbsSy: 0), 0)
        XCTAssertEqual(feetFromTons(0, widthFt: 12, rateLbsSy: 165), 0)

        let targetRate = spreadRateFromThickness(2)
        let actualRate = spreadRatePlaced(tons: 22, lengthFt: 150, widthFt: 12, firstPass: false)
        let reachableFeet = feetFromTons(40, widthFt: 12, rateLbsSy: targetRate)
        expectClose(targetRate, 220, digits: 4)
        expectClose(actualRate, 220, digits: 4)
        expectClose(reachableFeet, 272.73, digits: 2)
    }

    func testActualSpreadRate() {
        let feet = feetFromTons(10, widthFt: 12, rateLbsSy: 165)
        expectClose(actualSpreadRate(tons: 10, distanceFt: feet, widthFt: 12), 165, digits: 2)
        XCTAssertEqual(actualSpreadRate(tons: 10, distanceFt: 0, widthFt: 12), 0)
        XCTAssertEqual(actualSpreadRate(tons: 10, distanceFt: 100, widthFt: 0), 0)
    }

    func testFeetFromLoads() {
        let expected = feetFromTons(18.5, widthFt: 12, rateLbsSy: 165)
        expectClose(feetFromLoads(loads: 1, widthFt: 12, rateLbsSy: 165), expected, digits: 4)
        let custom = feetFromTons(20, widthFt: 12, rateLbsSy: 165)
        expectClose(
            feetFromLoads(loads: 1, tonsPerLoad: 20, widthFt: 12, rateLbsSy: 165),
            custom,
            digits: 4
        )
        XCTAssertEqual(feetFromLoads(loads: 0, widthFt: 12, rateLbsSy: 165), 0)
    }

    func testFeetFromOrderedMinusPlaced() {
        let expected = feetFromTons(40, widthFt: 12, rateLbsSy: 165)
        expectClose(
            feetFromOrderedMinusPlaced(tonsOrdered: 100, tonsPlaced: 60, widthFt: 12, rateLbsSy: 165),
            expected,
            digits: 4
        )
        XCTAssertEqual(
            feetFromOrderedMinusPlaced(tonsOrdered: 100, tonsPlaced: 100, widthFt: 12, rateLbsSy: 165),
            0
        )
        XCTAssertLessThan(
            feetFromOrderedMinusPlaced(tonsOrdered: 100, tonsPlaced: 120, widthFt: 12, rateLbsSy: 165),
            0
        )
    }

    func testTackGallons() {
        expectClose(tackGallons(100, 12, 0.065), 8.667, digits: 2)
        expectClose(tackGallons(1320, 24, 0.05), 176, digits: 2)
        expectClose(tackGallons(1320, 24, 0.08), 281.6, digits: 2)
        XCTAssertEqual(tackGallons(0, 12, 0.065), 0)
    }

    func testTonnageToOrder() {
        expectClose(tonnageToOrder(lengthFt: 100, widthFt: 18, rateLbsSy: 165), 16.5, digits: 4)
        expectClose(
            tonnageToOrder(lengthFt: 100, widthFt: 18, rateLbsSy: 165, wastePct: 5),
            17.325,
            digits: 4
        )
        XCTAssertEqual(tonnageToOrder(lengthFt: 0, widthFt: 18, rateLbsSy: 165), 0)
        XCTAssertEqual(tonnageToOrder(lengthFt: 100, widthFt: 18, rateLbsSy: 0), 0)
        expectClose(
            tonnageToOrder(lengthFt: 100, widthFt: 18, rateLbsSy: 165, wastePct: 200),
            49.5,
            digits: 4
        )
    }

    func testStickCheck() {
        expectClose(stickCheck(2), 2.5, digits: 4)
        expectClose(stickCheck(1.5), 1.875, digits: 4)
        XCTAssertEqual(stickCheck(0), 0)
    }

    func testTonsToMatchRateRoundsLikeTheWebSnapButton() {
        // 100 ft × 18 ft = 200 SY at 165 lbs/SY = 16.5 tons exactly.
        expectClose(tonsToMatchRate(lengthFt: 100, widthFt: 18, rateLbsSy: 165), 16.5, digits: 4)
    }
}
