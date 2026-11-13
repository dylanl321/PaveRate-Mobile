import XCTest
@testable import PaveRateCore

/// Mirrors `src/lib/calc/__tests__/checks.test.ts`.
final class CheckTests: XCTestCase {
    func testPlacementCheck() {
        XCTAssertNil(placementCheck(airTempF: nil, thicknessIn: 2))
        XCTAssertNil(placementCheck(airTempF: 50, thicknessIn: 0))

        let passTwoInch = placementCheck(airTempF: 50, thicknessIn: 2)
        XCTAssertEqual(passTwoInch?.status, .pass)
        XCTAssertEqual(passTwoInch?.minTempF, 45)

        XCTAssertEqual(placementCheck(airTempF: 40, thicknessIn: 2)?.status, .warn)
        XCTAssertEqual(placementCheck(airTempF: 39, thicknessIn: 2)?.status, .fail)

        let passOneInch = placementCheck(airTempF: 60, thicknessIn: 1)
        XCTAssertEqual(passOneInch?.status, .pass)
        XCTAssertEqual(passOneInch?.minTempF, 55)
        XCTAssertEqual(placementCheck(airTempF: 50, thicknessIn: 1)?.status, .warn)
        XCTAssertEqual(placementCheck(airTempF: 49, thicknessIn: 1)?.status, .fail)

        let passThree = placementCheck(airTempF: 45, thicknessIn: 3)
        XCTAssertEqual(passThree?.status, .pass)
        XCTAssertEqual(passThree?.minTempF, 40)

        let passFour = placementCheck(airTempF: 36, thicknessIn: 4)
        XCTAssertEqual(passFour?.status, .pass)
        XCTAssertEqual(passFour?.minTempF, 35)

        let passEight = placementCheck(airTempF: 33, thicknessIn: 8)
        XCTAssertEqual(passEight?.status, .pass)
        XCTAssertEqual(passEight?.minTempF, 32)
        XCTAssertEqual(placementCheck(airTempF: 30, thicknessIn: 8)?.status, .warn)
        XCTAssertEqual(placementCheck(airTempF: 26, thicknessIn: 8)?.status, .fail)

        // The web test is named "warn" for 48°F on a 2 in. lift, but 48 ≥ 45 so the
        // implementation returns pass. The test body only asserts a non-null result.
        XCTAssertEqual(placementCheck(airTempF: 48, thicknessIn: 2)?.status, .pass)
        XCTAssertEqual(placementCheck(airTempF: 43, thicknessIn: 2)?.status, .warn)
        XCTAssertEqual(placementCheck(airTempF: 60, thicknessIn: 2)?.clause, "§400.3.05.E Table 4")

        // Above 8 in. the lookup keeps the last Table 4 row.
        XCTAssertEqual(placementCheck(airTempF: 33, thicknessIn: 9)?.minTempF, 32)
        // 1.0 in. is the ≤1 in. row. 1.1 in. is the next row.
        XCTAssertEqual(placementCheck(airTempF: 60, thicknessIn: 1.0)?.minTempF, 55)
        XCTAssertEqual(placementCheck(airTempF: 50, thicknessIn: 1.1)?.minTempF, 45)
        XCTAssertEqual(placementCheck(airTempF: 50, thicknessIn: 2.0)?.minTempF, 45)
        XCTAssertEqual(placementCheck(airTempF: 45, thicknessIn: 2.1)?.minTempF, 40)
    }

    func testSpreadSpecCheck() {
        XCTAssertNil(spreadSpecCheck(placedLbsSy: nil, targetLbsSy: 165, courseId: nil))
        XCTAssertNil(spreadSpecCheck(placedLbsSy: 165, targetLbsSy: nil, courseId: nil))
        XCTAssertNil(spreadSpecCheck(placedLbsSy: 165, targetLbsSy: 0, courseId: nil))

        let good = spreadSpecCheck(placedLbsSy: 165, targetLbsSy: 165, courseId: nil)
        XCTAssertEqual(good?.status, .good)
        XCTAssertEqual(good?.clause, "§400.4.A.2.b Table 12")
        XCTAssertEqual(good?.toleranceLbsSy, 27.5)
        XCTAssertEqual(
            good?.message,
            "Within ±27.5 lbs/SY (Table 12, Intermediate / wearing course)"
        )

        XCTAssertEqual(spreadSpecCheck(placedLbsSy: 400, targetLbsSy: 165, courseId: nil)?.status, .bad)
        XCTAssertEqual(spreadSpecCheck(placedLbsSy: 50, targetLbsSy: 165, courseId: nil)?.status, .bad)
        XCTAssertGreaterThan(spreadSpecCheck(placedLbsSy: 170, targetLbsSy: 165, courseId: nil)?.deltaLbsSy ?? 0, 0)
        XCTAssertLessThan(spreadSpecCheck(placedLbsSy: 160, targetLbsSy: 165, courseId: nil)?.deltaLbsSy ?? 0, 0)

        // ±tolerance is still good. Up to 1.5× is warn. Past that is bad.
        XCTAssertEqual(spreadSpecCheck(placedLbsSy: 165 + 27.5, targetLbsSy: 165, courseId: nil)?.status, .good)
        XCTAssertEqual(spreadSpecCheck(placedLbsSy: 165 + 30, targetLbsSy: 165, courseId: nil)?.status, .warn)
        XCTAssertEqual(spreadSpecCheck(placedLbsSy: 165 + 41.25, targetLbsSy: 165, courseId: nil)?.status, .warn)
        XCTAssertEqual(spreadSpecCheck(placedLbsSy: 165 + 41.26, targetLbsSy: 165, courseId: nil)?.status, .bad)

        XCTAssertEqual(
            spreadSpecCheck(placedLbsSy: 220, targetLbsSy: 165, courseId: "TOLERANCE.BASE")?.toleranceLbsSy,
            55
        )
        XCTAssertEqual(
            spreadSpecCheck(placedLbsSy: 172, targetLbsSy: 165, courseId: "TOLERANCE.OGFC")?.status,
            .good
        )
        XCTAssertEqual(
            spreadSpecCheck(placedLbsSy: 173, targetLbsSy: 165, courseId: "TOLERANCE.OGFC")?.status,
            .warn
        )
        XCTAssertEqual(
            spreadSpecCheck(placedLbsSy: 175, targetLbsSy: 165, courseId: "TOLERANCE.PEM")?.status,
            .good
        )
    }

    func testTackTempCheck() {
        XCTAssertNil(tackTempCheck(airTempF: nil))
        let cold = tackTempCheck(airTempF: 35)
        XCTAssertEqual(cold?.status, .fail)
        XCTAssertEqual(cold?.clause, "§413.3.05.A")
        XCTAssertEqual(tackTempCheck(airTempF: 50)?.status, .pass)
        XCTAssertEqual(tackTempCheck(airTempF: 42)?.status, .warn)
        // Named "pass" in the web suite, but the assertion expects warn.
        XCTAssertEqual(tackTempCheck(airTempF: 40)?.status, .warn)
        XCTAssertEqual(tackTempCheck(airTempF: 45)?.status, .pass)
    }

    func testRainCheck() {
        XCTAssertNil(rainCheck(totalRainIn: nil))
        XCTAssertEqual(rainCheck(totalRainIn: 0)?.status, .pass)
        XCTAssertEqual(rainCheck(totalRainIn: 0.01)?.status, .warn)
        XCTAssertEqual(rainCheck(totalRainIn: 0.05)?.status, .warn)
        XCTAssertEqual(rainCheck(totalRainIn: 0.10)?.status, .fail)
        XCTAssertEqual(rainCheck(totalRainIn: 1.0)?.status, .fail)
        expectClose(rainCheck(totalRainIn: 0.30)?.totalIn ?? -1, 0.30, digits: 4)
        XCTAssertEqual(rainCheck(totalRainIn: 0.5)?.clause, "§400.3.05.E")
        XCTAssertEqual(
            rainCheck(totalRainIn: 0.30)?.message,
            "0.30 in rain forecast — do not pave or tack on wet surfaces"
        )
    }

    func testOpenGradedFloor() {
        XCTAssertNil(openGradedAirTempCheck(airTempF: 70, courseId: "TOLERANCE.INTERMEDIATE_WEARING"))
        XCTAssertEqual(openGradedAirTempCheck(airTempF: 60, courseId: "ogfc")?.status, .pass)
        XCTAssertEqual(openGradedAirTempCheck(airTempF: 55, courseId: "ogfc")?.status, .warn)
        XCTAssertEqual(openGradedAirTempCheck(airTempF: 54, courseId: "pem")?.status, .fail)
        XCTAssertEqual(openGradedAirTempCheck(airTempF: 59, courseId: "TOLERANCE.OGFC")?.status, .warn)
        XCTAssertEqual(openGradedAirTempCheck(airTempF: 70, courseId: "TOLERANCE.PEM")?.label, "PEM")
    }
}
