import XCTest
@testable import PaveRateCore

/// The YAML file is the transcribed config. These tests fail if Swift drifts from it.
final class ConfigParityTests: XCTestCase {
    func testConstantsMatchYAML() throws {
        let yaml = try asphaltConfigYAML()
        let keys = ["SF_PER_SY", "LB_PER_TON", "TRUCK_LOAD", "SHUTTLE_RETAIN", "PAVER_RETAIN", "THICK_MULT", "STICK_FACTOR"]
        for key in keys {
            let fromYAML = try XCTUnwrap(yamlValue(under: key, in: yaml))
            XCTAssertEqual(PaveRateConfig.constant(key), fromYAML, key)
        }
    }

    func testMachinesTackAndTolerancesMatchYAML() throws {
        let yaml = try asphaltConfigYAML()
        XCTAssertTrue(yaml.contains("retainTons: 14"))
        XCTAssertTrue(yaml.contains("retainTons: 24"))
        XCTAssertEqual(PaveRateConfig.machines.map(\.retainTons), [14, 24, 24, 0])
        XCTAssertEqual(PaveRateConfig.tackField.map(\.id), [
            "TACK.FIELD_LEVELING",
            "TACK.FIELD_TOPPING",
            "TACK.FIELD_OGI",
            "TACK.FIELD_ROCKCHIP"
        ])
        XCTAssertEqual(PaveRateConfig.tackField.map(\.min), [0.040, 0.040, 0.060, 0.085])
        XCTAssertEqual(PaveRateConfig.tackField.map(\.max), [0.060, 0.060, 0.080, 0.085])
        XCTAssertEqual(PaveRateConfig.spreadTolerance.map(\.toleranceLbsSy), [55, 27.5, 7, 10])
        XCTAssertEqual(PaveRateConfig.temperature.map(\.minAirTempF), [55, 45, 40, 35, 32])
        XCTAssertEqual(PaveRateConfig.weather.rainWarnIn, 0.01)
        XCTAssertEqual(PaveRateConfig.weather.rainBlockIn, 0.10)
        XCTAssertEqual(PaveRateConfig.weather.tackMinAirTempF, 40)
        XCTAssertEqual(PaveRateConfig.weather.ogfcMinAirTempF, 60)
        XCTAssertTrue(yaml.contains("ogfcMinAirTempF: 60"))
        XCTAssertTrue(yaml.contains("toleranceLbsSy: 27.5"))
        XCTAssertEqual(PaveRateConfig.table12.count, 5)
        XCTAssertEqual(JobSetup().widthFt, 12)
        XCTAssertEqual(JobSetup().thicknessIn, 1.5)
        XCTAssertEqual(JobSetup().truckLoadTons, 18.5)
        XCTAssertEqual(JobSetup().courseTypeId, "TOLERANCE.INTERMEDIATE_WEARING")
    }
}
