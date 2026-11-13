import SwiftUI

enum FieldAppearance: String, Codable, CaseIterable {
    case sunlight
    case glare
    case night

    var title: String {
        switch self {
        case .sunlight: return "Sunlight"
        case .glare: return "Glare"
        case .night: return "Night"
        }
    }
}

enum StatusKind: Equatable {
    case good
    case warn
    case bad
}

extension SpreadSpecStatus {
    var kind: StatusKind {
        switch self {
        case .good: return .good
        case .warn: return .warn
        case .bad: return .bad
        }
    }
}

extension PlacementStatus {
    var kind: StatusKind {
        switch self {
        case .pass: return .good
        case .warn: return .warn
        case .fail: return .bad
        }
    }
}

/// High-contrast colors from the web app's sunlight and dark theme tokens.
struct FieldPalette {
    let background: Color
    let surface: Color
    let surfaceAlt: Color
    let border: Color
    let text: Color
    let muted: Color
    let accent: Color
    let accentText: Color
    let good: Color
    let warn: Color
    let bad: Color
    let borderWidth: CGFloat
    let heroPoints: CGFloat
    let fieldPoints: CGFloat
    let minControl: CGFloat

    static let sunlight = FieldPalette(
        background: Color(red: 1, green: 1, blue: 1),
        surface: Color(red: 0.973, green: 0.973, blue: 0.973),
        surfaceAlt: Color(red: 0.937, green: 0.937, blue: 0.937),
        border: .black,
        text: .black,
        muted: Color(red: 0.2, green: 0.2, blue: 0.2),
        accent: Color(red: 0.961, green: 0.659, blue: 0),
        accentText: .black,
        good: Color(red: 0, green: 0.478, blue: 0.184),
        warn: Color(red: 0.753, green: 0.345, blue: 0),
        bad: Color(red: 0.8, green: 0, blue: 0),
        borderWidth: 3,
        heroPoints: 68,
        fieldPoints: 36,
        minControl: 76
    )

    static let glare = FieldPalette(
        background: .white,
        surface: .white,
        surfaceAlt: Color(red: 1, green: 0.96, blue: 0.8),
        border: .black,
        text: .black,
        muted: .black,
        accent: Color(red: 0.961, green: 0.659, blue: 0),
        accentText: .black,
        good: Color(red: 0, green: 0.35, blue: 0.12),
        warn: Color(red: 0.55, green: 0.22, blue: 0),
        bad: Color(red: 0.7, green: 0, blue: 0),
        borderWidth: 4,
        heroPoints: 76,
        fieldPoints: 40,
        minControl: 88
    )

    static let night = FieldPalette(
        background: Color(red: 0.106, green: 0.133, blue: 0.157),
        surface: Color(red: 0.137, green: 0.173, blue: 0.204),
        surfaceAlt: Color(red: 0.180, green: 0.231, blue: 0.275),
        border: Color(red: 0.216, green: 0.267, blue: 0.310),
        text: Color(red: 0.957, green: 0.965, blue: 0.969),
        muted: Color(red: 0.624, green: 0.690, blue: 0.741),
        accent: Color(red: 0.949, green: 0.753, blue: 0.216),
        accentText: Color(red: 0.106, green: 0.133, blue: 0.157),
        good: Color(red: 0.247, green: 0.698, blue: 0.498),
        warn: Color(red: 0.878, green: 0.573, blue: 0.184),
        bad: Color(red: 0.847, green: 0.345, blue: 0.310),
        borderWidth: 1,
        heroPoints: 64,
        fieldPoints: 34,
        minControl: 72
    )

    static func palette(for appearance: FieldAppearance) -> FieldPalette {
        switch appearance {
        case .sunlight: return .sunlight
        case .night: return .night
        case .glare: return .glare
        }
    }

    func status(_ kind: StatusKind) -> Color {
        switch kind {
        case .good: return good
        case .warn: return warn
        case .bad: return bad
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = FieldPalette.sunlight
}

extension EnvironmentValues {
    var fieldPalette: FieldPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
