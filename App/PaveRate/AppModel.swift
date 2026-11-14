import Foundation
import PaveRateCore

struct ToolInputs: Codable, Equatable {
    var spreadTons: String = ""
    var spreadDistance: String = ""
    var spreadCustomRate: String = ""
    var spreadOverride: Bool = false
    var feetOrdered: String = ""
    var feetPlaced: String = ""
    var feetTotalLength: String = ""
    var tackLength: String = ""
    var tonnageLength: String = ""
    var stickTarget: String = "1.5"
    var plannerSilo: String = ""
    var plannerTrucks: String = ""
    var plannerDesired: String = ""
}

enum RunDrawMode: String, Codable {
    case plan
    case paved
}

struct SavedRoute: Codable, Equatable, Sendable {
    var routeID: String
    var name: String
    var county: String
    var lines: [[GeoPoint]]
}

private struct PersistedV1: Codable {
    var job: JobSetup
    var appearance: FieldAppearance
    var inputs: ToolInputs
}

private struct PersistedV2: Codable {
    var job: JobSetup
    var appearance: FieldAppearance
    var inputs: ToolInputs
    var plannedPoints: [GeoPoint]
    var pavedPoints: [GeoPoint]
    var loads: [LoadTicket]
    var weather: WeatherReading?
    var followsWeather: Bool
    var airTempManual: Bool
    var rainManual: Bool
    var savedRoute: SavedRoute?
    var drawMode: RunDrawMode
}

private struct EditSnapshot {
    var job: JobSetup
    var inputs: ToolInputs
    var plannedPoints: [GeoPoint]
    var pavedPoints: [GeoPoint]
    var loads: [LoadTicket]
    var cachedWeather: WeatherReading?
    var followsWeather: Bool
    var airTempManual: Bool
    var rainManual: Bool
    var savedRoute: SavedRoute?
}

@MainActor
@Observable
final class AppModel {
    var job: JobSetup { didSet { persist() } }
    var appearance: FieldAppearance { didSet { persist() } }
    var inputs: ToolInputs { didSet { persist() } }
    var plannedPoints: [GeoPoint] = [] { didSet { persist() } }
    var pavedPoints: [GeoPoint] = [] { didSet { persist() } }
    var loads: [LoadTicket] = [] { didSet { persist() } }
    var cachedWeather: WeatherReading? { didSet { persist() } }
    var followsWeather: Bool = true { didSet { persist() } }
    var airTempManual: Bool = false { didSet { persist() } }
    var rainManual: Bool = false { didSet { persist() } }
    var savedRoute: SavedRoute? { didSet { persist() } }
    var drawMode: RunDrawMode = .plan { didSet { persist() } }

    private(set) var undoCount = 0
    var canUndo: Bool { undoCount > 0 }

    private var undoStack: [EditSnapshot] = []
    private let defaults: UserDefaults
    private let storageKey = "paverate.mobile.v2"
    private let legacyKey = "paverate.mobile.v1"
    private var isLoading = false
    private var weatherRequestInFlight = false

    init(job: JobSetup, appearance: FieldAppearance, inputs: ToolInputs, defaults: UserDefaults = .standard) {
        self.job = job
        self.appearance = appearance
        self.inputs = inputs
        self.defaults = defaults
    }

    static func load(defaults: UserDefaults = .standard) -> AppModel {
        let model = AppModel(job: JobSetup(), appearance: .sunlight, inputs: ToolInputs(), defaults: defaults)
        model.isLoading = true
        defer { model.isLoading = false }
        if let data = defaults.data(forKey: model.storageKey),
           let saved = try? JSONDecoder().decode(PersistedV2.self, from: data) {
            model.apply(saved)
            return model
        }
        guard let data = defaults.data(forKey: model.legacyKey),
              let saved = try? JSONDecoder().decode(PersistedV1.self, from: data) else {
            return model
        }
        model.job = saved.job
        model.appearance = saved.appearance
        model.inputs = saved.inputs
        model.airTempManual = saved.job.airTempF != nil
        model.rainManual = saved.job.rainNext24hIn != nil
        return model
    }

    var runMeasure: RunMeasure {
        GeoMeasure.measure(planned: plannedPoints, paved: pavedPoints, widthFt: job.widthFt)
    }

    var tonsPlacedToday: Double? {
        if !loads.isEmpty { return LoadLedger.tonsPlaced(loads) }
        return parseField(inputs.feetPlaced)
    }

    var weatherDecision: WeatherDecision? {
        guard let cachedWeather else { return nil }
        return WeatherDecisions.decide(reading: cachedWeather, job: job)
    }

    func checkpoint() {
        undoStack.append(snapshot())
        if undoStack.count > 20 { undoStack.removeFirst() }
        undoCount = undoStack.count
    }

    func undoLastChange() {
        guard let previous = undoStack.popLast() else { return }
        isLoading = true
        job = previous.job
        inputs = previous.inputs
        plannedPoints = previous.plannedPoints
        pavedPoints = previous.pavedPoints
        loads = previous.loads
        cachedWeather = previous.cachedWeather
        followsWeather = previous.followsWeather
        airTempManual = previous.airTempManual
        rainManual = previous.rainManual
        savedRoute = previous.savedRoute
        isLoading = false
        undoCount = undoStack.count
        persist()
    }

    func clear(_ tool: FieldTool) {
        checkpoint()
        switch tool {
        case .spreadRate:
            inputs.spreadTons = ""
            inputs.spreadDistance = ""
            inputs.spreadCustomRate = ""
            inputs.spreadOverride = false
        case .feetLeft:
            inputs.feetOrdered = ""
            inputs.feetPlaced = ""
            inputs.feetTotalLength = ""
        case .distancePlanner:
            inputs.plannerSilo = ""
            inputs.plannerTrucks = ""
            inputs.plannerDesired = ""
        case .tonnage:
            inputs.tonnageLength = ""
        case .tack:
            inputs.tackLength = ""
        case .stickCheck:
            inputs.stickTarget = "1.5"
        case .pavingWindow:
            break
        }
    }

    func dropPoint(_ point: GeoPoint) {
        checkpoint()
        switch drawMode {
        case .plan:
            guard plannedPoints.count < 500 else { return }
            plannedPoints.append(point)
        case .paved:
            guard pavedPoints.count < GeoMeasure.maxTrackPoints else { return }
            pavedPoints.append(point)
        }
    }

    func undoPoint() {
        switch drawMode {
        case .plan:
            guard !plannedPoints.isEmpty else { return }
            checkpoint()
            plannedPoints.removeLast()
        case .paved:
            guard !pavedPoints.isEmpty else { return }
            checkpoint()
            pavedPoints.removeLast()
        }
    }

    func clearActiveLine() {
        checkpoint()
        switch drawMode {
        case .plan:
            plannedPoints = []
        case .paved:
            pavedPoints = []
        }
    }

    func appendTrack(_ point: GeoPoint, accuracyMeters: Double) {
        let updated = GeoMeasure.appendTrackPoint(pavedPoints, next: point, accuracyMeters: accuracyMeters)
        if updated != pavedPoints {
            pavedPoints = updated
        }
    }

    func applyRunLengthToJob() {
        applyLength(runMeasure.lengthForCalcs)
    }

    func applyLength(_ feet: Double) {
        guard feet > 0 else { return }
        let text = displayNumber(feet)
        checkpoint()
        inputs.tonnageLength = text
        inputs.tackLength = text
        inputs.spreadDistance = text
        inputs.feetTotalLength = text
    }

    func addLoad(truck: String, tons: Double, coveredFeet: Double?) {
        guard tons > 0 else { return }
        checkpoint()
        loads.append(LoadTicket(
            truck: truck.trimmingCharacters(in: .whitespacesAndNewlines),
            tons: tons,
            coveredFeet: coveredFeet,
            recordedAt: Date()
        ))
    }

    func deleteLoad(_ id: UUID) {
        guard loads.contains(where: { $0.id == id }) else { return }
        checkpoint()
        loads.removeAll { $0.id == id }
    }

    func startNewDay() {
        checkpoint()
        loads = []
        pavedPoints = []
        inputs.feetPlaced = ""
        inputs.feetOrdered = ""
        inputs.spreadTons = ""
        inputs.spreadDistance = ""
        inputs.plannerSilo = ""
        inputs.plannerTrucks = ""
        inputs.plannerDesired = ""
    }

    /// Pull a new reading for this spot and fill the job. Clears a manual lock.
    @discardableResult
    func pullWeather(at point: GeoPoint) async -> Bool {
        if weatherRequestInFlight { return false }
        weatherRequestInFlight = true
        defer { weatherRequestInFlight = false }
        guard let reading = await FieldWeatherFetch.load(latitude: point.latitude, longitude: point.longitude) else {
            return false
        }
        checkpoint()
        airTempManual = false
        rainManual = false
        followsWeather = true
        cachedWeather = reading
        job = WeatherPolicy.applying(
            reading,
            to: job,
            policy: WeatherApplyPolicy(replaceAir: true, replaceRain: true, setSurfaceWet: true)
        )
        return true
    }

    /// Use a saved reading even when it is old or was taken somewhere else, then leave it alone.
    func useSavedReading() {
        guard let cachedWeather else { return }
        checkpoint()
        job = WeatherPolicy.applying(
            cachedWeather,
            to: job,
            policy: WeatherApplyPolicy(replaceAir: true, replaceRain: true, setSurfaceWet: true)
        )
        airTempManual = true
        rainManual = true
    }

    /// Refresh when the saved reading is old. A fresh one is applied only if the fields are not locked.
    func refreshWeatherIfNeeded(at point: GeoPoint) async {
        if weatherRequestInFlight { return }
        if let cachedWeather,
           Date().timeIntervalSince(cachedWeather.fetchedAt) < WeatherPolicy.freshSeconds,
           !WeatherPolicy.hasDrifted(reading: cachedWeather, current: point) {
            follow(cachedWeather, at: point)
            return
        }
        weatherRequestInFlight = true
        defer { weatherRequestInFlight = false }
        if let reading = await FieldWeatherFetch.load(latitude: point.latitude, longitude: point.longitude) {
            let updated = followedJob(reading, at: point)
            if updated != job || cachedWeather != reading {
                checkpoint()
                cachedWeather = reading
                job = updated
            }
            return
        }
        if let cachedWeather {
            follow(cachedWeather, at: point)
        }
    }

    private func follow(_ reading: WeatherReading, at point: GeoPoint) {
        let updated = followedJob(reading, at: point)
        guard updated != job else { return }
        checkpoint()
        job = updated
    }

    private func followedJob(_ reading: WeatherReading, at point: GeoPoint) -> JobSetup {
        let policy = WeatherPolicy.applyPolicy(
            freshness: WeatherPolicy.freshness(fetchedAt: reading.fetchedAt, now: Date()),
            followsGPS: followsWeather,
            airLocked: airTempManual,
            rainLocked: rainManual,
            drifted: WeatherPolicy.hasDrifted(reading: reading, current: point)
        )
        return WeatherPolicy.applying(reading, to: job, policy: policy)
    }

    private func apply(_ saved: PersistedV2) {
        job = saved.job
        appearance = saved.appearance
        inputs = saved.inputs
        plannedPoints = saved.plannedPoints
        pavedPoints = saved.pavedPoints
        loads = saved.loads
        cachedWeather = saved.weather
        followsWeather = saved.followsWeather
        airTempManual = saved.airTempManual
        rainManual = saved.rainManual
        savedRoute = saved.savedRoute
        drawMode = saved.drawMode
    }

    private func snapshot() -> EditSnapshot {
        EditSnapshot(
            job: job,
            inputs: inputs,
            plannedPoints: plannedPoints,
            pavedPoints: pavedPoints,
            loads: loads,
            cachedWeather: cachedWeather,
            followsWeather: followsWeather,
            airTempManual: airTempManual,
            rainManual: rainManual,
            savedRoute: savedRoute
        )
    }

    private func persist() {
        guard !isLoading else { return }
        let snapshot = PersistedV2(
            job: job,
            appearance: appearance,
            inputs: inputs,
            plannedPoints: plannedPoints,
            pavedPoints: pavedPoints,
            loads: loads,
            weather: cachedWeather,
            followsWeather: followsWeather,
            airTempManual: airTempManual,
            rainManual: rainManual,
            savedRoute: savedRoute,
            drawMode: drawMode
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

func parseField(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let normalized = trimmed.replacingOccurrences(of: ",", with: "")
    return Double(normalized)
}

func displayNumber(_ value: Double) -> String {
    if value == value.rounded() && abs(value) < 1e15 {
        return String(Int(value.rounded()))
    }
    var text = FieldFormat.fixed(value, digits: 4)
    while text.contains(".") && text.hasSuffix("0") {
        text.removeLast()
    }
    if text.hasSuffix(".") {
        text.removeLast()
    }
    return text
}
