import XCTest
@testable import PaveRateCore

final class WeatherDecisionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_592_800) // 2026-11-13 18:00:00 UTC

    func testOpenMeteoParseSumsTheNextDayAndRoundsAir() throws {
        let json = """
        {
          "utc_offset_seconds": 0,
          "current": {
            "temperature_2m": 62.4,
            "weather_code": 3,
            "precipitation": 0,
            "wind_speed_10m": 8.4,
            "wind_direction_10m": 220,
            "wind_gusts_10m": 14
          },
          "hourly": {
            "time": [
              "2026-11-13T17:00",
              "2026-11-13T18:00",
              "2026-11-13T19:00",
              "2026-11-13T20:00"
            ],
            "precipitation": [5, 0, 1.27, 1.27],
            "precipitation_probability": [10, 0, 60, 10],
            "weather_code": [3, 3, 61, 1],
            "temperature_2m": [63, 62.4, 61, 60],
            "soil_temperature_0cm": [51.2, 51.4, 51.0, 50.8],
            "wind_speed_10m": [8, 8.4, 9, 9]
          }
        }
        """.data(using: .utf8)!
        let reading = try OpenMeteoParser.parse(
            data: json,
            latitude: 33.75,
            longitude: -84.39,
            now: now
        )
        XCTAssertEqual(reading.airTempF, 62)
        XCTAssertEqual(reading.conditions, "Overcast")
        XCTAssertFalse(reading.isRaining)
        XCTAssertFalse(reading.isSnowing)
        XCTAssertEqual(reading.groundTempF, 51)
        XCTAssertEqual(reading.windDirectionDeg, 220)
        XCTAssertEqual(reading.hours.count, 3)
        expectClose(reading.rainNext24hIn, 0.1, digits: 4)
        XCTAssertEqual(WeatherDecisions.rainThreats(in: reading.hours).count, 2)
        XCTAssertEqual(reading.source, .openMeteo)
    }

    func testRainAndSnowCodes() throws {
        let json = """
        {"utc_offset_seconds":0,"current":{"temperature_2m":30,"weather_code":71,"precipitation":0},"hourly":{"time":[],"precipitation":[]}}
        """.data(using: .utf8)!
        let reading = try OpenMeteoParser.parse(data: json, latitude: 1, longitude: 2, now: now)
        XCTAssertTrue(reading.isSnowing)
        XCTAssertTrue(reading.suggestsWetSurface)
        XCTAssertFalse(reading.isRaining)
    }

    func testRejectsABodyWithNoConditions() {
        let json = #"{"utc_offset_seconds":0}"#.data(using: .utf8)!
        XCTAssertThrowsError(try OpenMeteoParser.parse(data: json, latitude: 0, longitude: 0, now: now))
    }

    func testMergeKeepsKitRainAndMeteoGround() {
        let kit = sample(air: 70, rain: 0, ground: nil, source: .weatherKit, hours: [])
        var meteo = sample(air: 68, rain: 0.2, ground: 55, source: .openMeteo, hours: [])
        meteo.hours = [ForecastHour(time: now, precipIn: 0.2, probability: 80)]
        let merged = OpenMeteoParser.merge(kit: kit, meteo: meteo)
        XCTAssertEqual(merged.airTempF, 70)
        XCTAssertEqual(merged.groundTempF, 55)
        XCTAssertEqual(merged.hours.count, 1)
        expectClose(merged.rainNext24hIn, 0.2, digits: 4)
        XCTAssertEqual(merged.source, .merged)
    }

    func testDecisionsFollowTable4TackAndRain() {
        let job = JobSetup()
        let clear = decide(air: 70, rain: 0, job: job)
        XCTAssertEqual(clear.headline, "OK to pave")
        XCTAssertEqual(clear.status, .pass)
        XCTAssertFalse(clear.suggestSurfaceWet)

        let borderline = decide(air: 42, rain: 0, job: job)
        XCTAssertEqual(borderline.headline, "Borderline — watch it")
        XCTAssertEqual(borderline.placement?.status, .warn)

        let cold = decide(air: 36, rain: 0, job: job)
        XCTAssertEqual(cold.headline, "Too cold to pave")
        XCTAssertEqual(cold.status, .fail)

        let trace = decide(air: 70, rain: 0.02, job: job)
        XCTAssertEqual(trace.rain?.status, .warn)
        XCTAssertEqual(trace.headline, "Borderline — watch it")

        let blocked = decide(air: 70, rain: 0.10, job: job)
        XCTAssertEqual(blocked.headline, "Hold — rain in the next 24 h")
        XCTAssertEqual(blocked.status, .fail)

        var wet = sample(air: 70, rain: 0, ground: nil, source: .openMeteo, hours: [])
        wet.isRaining = true
        XCTAssertTrue(WeatherDecisions.decide(reading: wet, job: job).suggestSurfaceWet)
    }

    func testOpenGradedAndTackHeadlines() {
        var ogfc = JobSetup()
        ogfc.courseTypeId = "TOLERANCE.OGFC"
        XCTAssertEqual(decide(air: 58, rain: 0, job: ogfc).headline, "Borderline — watch it")
        XCTAssertEqual(decide(air: 50, rain: 0, job: ogfc).headline, "Too cold for OGFC")

        var thick = JobSetup()
        thick.thicknessIn = 4
        XCTAssertEqual(decide(air: 39, rain: 0, job: thick).headline, "Too cold to tack")
        XCTAssertEqual(decide(air: 39, rain: 0, job: thick).placement?.status, .pass)
    }

    func testWindAndFrozenGroundAreNotesNotSpecFails() {
        var windy = sample(air: 70, rain: 0, ground: 40, source: .openMeteo, hours: [])
        windy.windMph = 16
        let note = WeatherDecisions.decide(reading: windy, job: JobSetup())
        XCTAssertEqual(note.status, .warn)
        XCTAssertTrue(note.windNote?.contains("not a GDOT cutoff") == true)
        XCTAssertEqual(note.headline, "Borderline — watch it")

        var storm = windy
        storm.windMph = 28
        storm.rainNext24hIn = 0.2
        let held = WeatherDecisions.decide(reading: storm, job: JobSetup())
        XCTAssertEqual(held.status, .fail)
        XCTAssertEqual(held.headline, "Hold — rain in the next 24 h")
        XCTAssertNotNil(held.windNote)

        let frozen = sample(air: 70, rain: 0, ground: 30, source: .openMeteo, hours: [])
        let ground = WeatherDecisions.decide(reading: frozen, job: JobSetup())
        XCTAssertEqual(ground.status, .warn)
        XCTAssertTrue(ground.groundNote?.contains("not an infrared") == true)
    }

    func testApplyNeverClearsAWetSurface() {
        var job = JobSetup()
        job.surfaceWet = true
        job.airTempF = 50
        let reading = sample(air: 70, rain: 0, ground: nil, source: .openMeteo, hours: [])
        let policy = WeatherApplyPolicy(replaceAir: true, replaceRain: true, setSurfaceWet: true)
        let updated = WeatherPolicy.applying(reading, to: job, policy: policy)
        XCTAssertTrue(updated.surfaceWet)
        XCTAssertEqual(updated.airTempF, 70)

        var raining = reading
        raining.isRaining = true
        let dry = JobSetup()
        let soaked = WeatherPolicy.applying(raining, to: dry, policy: policy)
        XCTAssertTrue(soaked.surfaceWet)

        let locked = WeatherApplyPolicy(replaceAir: false, replaceRain: false, setSurfaceWet: false)
        let untouched = WeatherPolicy.applying(raining, to: dry, policy: locked)
        XCTAssertFalse(untouched.surfaceWet)
        XCTAssertNil(untouched.airTempF)
    }

    func testFreshnessDriftAndAutoApply() {
        XCTAssertEqual(WeatherPolicy.freshness(fetchedAt: now, now: now.addingTimeInterval(60)), .fresh)
        XCTAssertEqual(WeatherPolicy.freshness(fetchedAt: now, now: now.addingTimeInterval(31 * 60)), .aging)
        XCTAssertEqual(WeatherPolicy.freshness(fetchedAt: now, now: now.addingTimeInterval(7 * 3600)), .stale)
        XCTAssertEqual(WeatherPolicy.ageText(fetchedAt: now, now: now), "just now")
        XCTAssertEqual(WeatherPolicy.ageText(fetchedAt: now, now: now.addingTimeInterval(4 * 60)), "4 min ago")

        let reading = sample(air: 70, rain: 0, ground: nil, source: .openMeteo, hours: [])
        let nearby = GeoPoint(latitude: 33.758, longitude: -84.39)
        XCTAssertFalse(WeatherPolicy.hasDrifted(reading: reading, current: nearby))
        XCTAssertFalse(WeatherPolicy.hasDrifted(reading: reading, current: nil))
        let away = GeoPoint(latitude: 34.75, longitude: -84.39)
        XCTAssertTrue(WeatherPolicy.hasDrifted(reading: reading, current: away))

        let trusted = WeatherPolicy.applyPolicy(
            freshness: .fresh,
            followsGPS: true,
            airLocked: false,
            rainLocked: true,
            drifted: false
        )
        XCTAssertTrue(trusted.replaceAir)
        XCTAssertFalse(trusted.replaceRain)

        let stale = WeatherPolicy.applyPolicy(
            freshness: .stale,
            followsGPS: true,
            airLocked: false,
            rainLocked: false,
            drifted: false
        )
        XCTAssertFalse(stale.replaceAir)
        XCTAssertFalse(stale.setSurfaceWet)

        let drifted = WeatherPolicy.applyPolicy(
            freshness: .fresh,
            followsGPS: true,
            airLocked: false,
            rainLocked: false,
            drifted: true
        )
        XCTAssertFalse(drifted.replaceAir)
    }

    private func decide(air: Double, rain: Double, job: JobSetup) -> WeatherDecision {
        WeatherDecisions.decide(reading: sample(air: air, rain: rain, ground: 60, source: .openMeteo, hours: []), job: job)
    }

    private func sample(
        air: Double,
        rain: Double,
        ground: Double?,
        source: WeatherSource,
        hours: [ForecastHour]
    ) -> WeatherReading {
        WeatherReading(
            airTempF: air,
            groundTempF: ground,
            conditions: "Clear",
            isRaining: false,
            rainNext24hIn: rain,
            hours: hours,
            fetchedAt: now,
            latitude: 33.75,
            longitude: -84.39,
            source: source
        )
    }
}
