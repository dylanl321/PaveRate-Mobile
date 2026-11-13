import XCTest
@testable import PaveRateCore

final class CalculatorTests: XCTestCase {
    func testFeetLeftShowWorkMatchesTheWebProof() {
        var job = JobSetup()
        job.widthFt = 12
        job.thicknessIn = 1.5
        let report = AsphaltCalculator.feetLeft(tonsOrdered: 100, tonsPlaced: 60, totalLengthFt: nil, job: job)
        expectClose(report.feet ?? -1, feetFromTons(40, widthFt: 12, rateLbsSy: 165), digits: 4)
        XCTAssertEqual(report.steps.map(\.label), [
            "Spread rate",
            "Remaining tons",
            "Remaining lbs",
            "Feet left"
        ])
        XCTAssertEqual(report.steps[0].formula, "1.50 × 110")
        XCTAssertEqual(report.steps[0].result, "165 lbs/SY")
        XCTAssertEqual(report.steps[1].result, "40.00 tons")
        XCTAssertEqual(report.steps[2].formula, "40.00 × 2000")
        XCTAssertEqual(report.steps[2].result, "80000 lbs")
        XCTAssertEqual(report.steps[3].formula, "80000 × 9 ÷ (12 × 165)")
        XCTAssertEqual(report.steps[3].result, "364 ft")
        XCTAssertEqual(report.headline, "364")
    }

    func testSpreadRateShowWorkSubtractsFirstPassRetention() {
        var job = JobSetup()
        job.widthFt = 18
        job.thicknessIn = 1.5
        job.machineId = "paver"
        job.firstPass = true
        let report = AsphaltCalculator.spreadRate(tons: 100, distanceFt: 100, customTargetLbsSy: nil, job: job)
        expectClose(report.placedLbsSy ?? -1, 860, digits: 1)
        XCTAssertEqual(report.spec?.status, .bad)
        XCTAssertEqual(report.steps[1].formula, "(100.00 − 14.00) × 2000")
        XCTAssertEqual(report.steps[1].result, "172000 lbs")
        XCTAssertEqual(report.steps[2].result, "860 lbs/SY")
        XCTAssertEqual(report.steps[4].result, "+695.0 lbs/SY")
    }

    func testSpreadRateTreatsZeroTonsAsMissing() {
        let report = AsphaltCalculator.spreadRate(tons: 0, distanceFt: 100, customTargetLbsSy: nil, job: JobSetup())
        XCTAssertNil(report.placedLbsSy)
        XCTAssertEqual(report.targetLbsSy, 165)
    }

    func testTackMidAndBlock() {
        var job = JobSetup()
        job.widthFt = 12
        job.tackApplicationId = "TACK.FIELD_LEVELING"
        job.airTempF = 35
        let report = AsphaltCalculator.tack(lengthFt: 100, job: job)
        expectClose(report.gallonsMid ?? -1, tackGallons(100, 12, 0.05), digits: 4)
        XCTAssertTrue(report.blocked)
        XCTAssertNil(report.suggestedGallons)
        XCTAssertEqual(report.steps[1].formula, "(0.040 + 0.060) ÷ 2")
        XCTAssertEqual(report.steps[2].result, "7 gal")
    }

    func testTonnageWasteSteps() {
        var job = JobSetup()
        job.widthFt = 18
        job.thicknessIn = 1.5
        job.wastePct = 5
        let report = AsphaltCalculator.tonnage(lengthFt: 100, job: job)
        expectClose(report.tons ?? -1, 17.325, digits: 4)
        XCTAssertEqual(report.steps[3].formula, "16.50 × 1.05")
        XCTAssertEqual(report.steps[3].result, "17.33 tons")
        XCTAssertEqual(report.headline, "17")
    }

    func testStickDefaultFactor() {
        let report = AsphaltCalculator.stick(compactedIn: 1.5)
        expectClose(report.looseIn ?? -1, 1.875, digits: 4)
        XCTAssertEqual(report.headline, "1.88")
        XCTAssertEqual(report.steps[0].formula, "1.50 × 1.25")
    }

    func testDistancePlannerReversesFeetFromTons() {
        var job = JobSetup()
        job.widthFt = 12
        job.thicknessIn = 1.5
        let report = AsphaltCalculator.distancePlan(
            tonsInSilo: 10,
            tonsInTrucks: 8.5,
            desiredDistanceFt: 200,
            job: job
        )
        let expectedFeet = feetFromTons(18.5, widthFt: 12, rateLbsSy: 165)
        expectClose(report.availableFeet ?? -1, expectedFeet, digits: 4)
        let expectedTons = (200.0 * 12 * 165) / (2000 * 9)
        expectClose(report.tonsNeeded ?? -1, expectedTons, digits: 4)
        XCTAssertEqual(report.steps.count, 3)
    }

    func testPavingWindowUsesTable4AndOgfcFloor() {
        var job = JobSetup()
        job.thicknessIn = 2
        job.airTempF = 50
        job.courseTypeId = "TOLERANCE.OGFC"
        let report = AsphaltCalculator.pavingWindow(job: job)
        XCTAssertEqual(report.check?.status, .pass)
        XCTAssertEqual(report.check?.minTempF, 45)
        XCTAssertEqual(report.headline, "45°F")
        XCTAssertEqual(report.openGraded?.status, .fail)
        XCTAssertEqual(report.matchedBand?.id, "TEMP.1_2IN")
    }
}
