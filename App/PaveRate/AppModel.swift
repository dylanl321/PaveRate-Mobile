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

private struct PersistedApp: Codable {
    var job: JobSetup
    var appearance: FieldAppearance
    var inputs: ToolInputs
}

@MainActor
@Observable
final class AppModel {
    var job: JobSetup {
        didSet { persist() }
    }

    var appearance: FieldAppearance {
        didSet { persist() }
    }

    var inputs: ToolInputs {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let storageKey = "paverate.mobile.v1"
    private var isLoading = false

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
        guard let data = defaults.data(forKey: model.storageKey),
              let saved = try? JSONDecoder().decode(PersistedApp.self, from: data) else {
            return model
        }
        model.job = saved.job
        model.appearance = saved.appearance
        model.inputs = saved.inputs
        return model
    }

    func clear(_ tool: FieldTool) {
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

    private func persist() {
        guard !isLoading else { return }
        let snapshot = PersistedApp(job: job, appearance: appearance, inputs: inputs)
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
