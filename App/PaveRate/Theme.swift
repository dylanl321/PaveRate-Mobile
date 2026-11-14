import PaveRateCore
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

/// Field is the glove layout. Compact is standard iOS sizing. Colors do not change with this.
enum FieldDensity: String, CaseIterable, Hashable {
    case field
    case compact

    static let storageKey = "paverate.layoutDensity"

    var title: String {
        switch self {
        case .field: return "Field"
        case .compact: return "Compact"
        }
    }

    var detail: String {
        switch self {
        case .field: return "Thick buttons and large type for gloves and sun."
        case .compact: return "Standard size. More of the shift on the screen."
        }
    }

    func layout(for appearance: FieldAppearance) -> FieldLayout {
        switch self {
        case .compact:
            return .compact
        case .field:
            switch appearance {
            case .sunlight: return .fieldSun
            case .glare: return .fieldGlare
            case .night: return .fieldNight
            }
        }
    }
}

/// Sizes for every screen. Views read these off the palette instead of branching on the mode.
struct FieldLayout: Equatable {
    var minControl: CGFloat
    var heroPoints: CGFloat
    var fieldPoints: CGFloat
    var pagePadding: CGFloat
    var stackSpacing: CGFloat
    var tightSpacing: CGFloat
    var cardPadding: CGFloat
    var cornerRadius: CGFloat
    var fontScale: CGFloat
    var keypadHeight: CGFloat
    var sliderMin: CGFloat
    var tagPoints: CGFloat
    var fieldTypeCap: CGFloat

    static let fieldSun = FieldLayout(
        minControl: 76, heroPoints: 68, fieldPoints: 36,
        pagePadding: 20, stackSpacing: 18, tightSpacing: 10, cardPadding: 16,
        cornerRadius: 14, fontScale: 1, keypadHeight: 56, sliderMin: 52, tagPoints: 16, fieldTypeCap: 1.6
    )
    static let fieldGlare = FieldLayout(
        minControl: 88, heroPoints: 76, fieldPoints: 40,
        pagePadding: 20, stackSpacing: 18, tightSpacing: 10, cardPadding: 18,
        cornerRadius: 16, fontScale: 1, keypadHeight: 60, sliderMin: 56, tagPoints: 17, fieldTypeCap: 1.6
    )
    static let fieldNight = FieldLayout(
        minControl: 72, heroPoints: 64, fieldPoints: 34,
        pagePadding: 20, stackSpacing: 16, tightSpacing: 8, cardPadding: 16,
        cornerRadius: 14, fontScale: 1, keypadHeight: 52, sliderMin: 48, tagPoints: 15, fieldTypeCap: 1.6
    )
    static let compact = FieldLayout(
        minControl: 44, heroPoints: 34, fieldPoints: 20,
        pagePadding: 12, stackSpacing: 10, tightSpacing: 6, cardPadding: 10,
        cornerRadius: 10, fontScale: 1, keypadHeight: 44, sliderMin: 44, tagPoints: 11, fieldTypeCap: 1.25
    )
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
    /// Ink painted on a good / warn / bad fill. Chosen so the word stays readable in sun.
    let onGood: Color
    let onWarn: Color
    let onBad: Color
    let borderWidth: CGFloat
    var layout: FieldLayout

    var heroPoints: CGFloat { layout.heroPoints }
    var fieldPoints: CGFloat { layout.fieldPoints }
    var minControl: CGFloat { layout.minControl }
    var pagePadding: CGFloat { layout.pagePadding }
    var stackSpacing: CGFloat { layout.stackSpacing }
    var tightSpacing: CGFloat { layout.tightSpacing }
    var cardPadding: CGFloat { layout.cardPadding }
    var cornerRadius: CGFloat { layout.cornerRadius }
    var fontScale: CGFloat { layout.fontScale }
    var keypadHeight: CGFloat { layout.keypadHeight }
    var sliderMin: CGFloat { layout.sliderMin }
    var tagPoints: CGFloat { layout.tagPoints }
    var fieldTypeCap: CGFloat { layout.fieldTypeCap }

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
        warn: Color(red: 0.60, green: 0.26, blue: 0),
        bad: Color(red: 0.8, green: 0, blue: 0),
        onGood: .white,
        onWarn: .white,
        onBad: .white,
        borderWidth: 3,
        layout: .fieldSun
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
        onGood: .white,
        onWarn: .white,
        onBad: .white,
        borderWidth: 4,
        layout: .fieldGlare
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
        onGood: .black,
        onWarn: .black,
        onBad: .black,
        borderWidth: 1,
        layout: .fieldNight
    )

    static func palette(for appearance: FieldAppearance, density: FieldDensity = .field) -> FieldPalette {
        var base: FieldPalette
        switch appearance {
        case .sunlight: base = .sunlight
        case .glare: base = .glare
        case .night: base = .night
        }
        base.layout = density.layout(for: appearance)
        return base
    }

    func status(_ kind: StatusKind) -> Color {
        switch kind {
        case .good: return good
        case .warn: return warn
        case .bad: return bad
        }
    }

    func onStatus(_ kind: StatusKind) -> Color {
        switch kind {
        case .good: return onGood
        case .warn: return onWarn
        case .bad: return onBad
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = FieldPalette.sunlight
}

enum OutdoorScale {
    /// Dynamic Type grows the outdoor size. It does not shrink below it.
    static func multiplier(_ size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall, .small, .medium, .large:
            return 1
        case .xLarge:
            return 1.12
        case .xxLarge:
            return 1.25
        case .xxxLarge:
            return 1.4
        case .accessibility1:
            return 1.6
        case .accessibility2:
            return 1.85
        case .accessibility3:
            return 2.1
        case .accessibility4:
            return 2.4
        case .accessibility5:
            return 2.7
        @unknown default:
            return 1
        }
    }
}

struct OutdoorFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.fieldPalette) private var palette
    var base: CGFloat
    var weight: Font.Weight = .bold

    func body(content: Content) -> some View {
        let size = base * palette.fontScale * OutdoorScale.multiplier(dynamicTypeSize)
        content.font(.system(size: size, weight: weight, design: .rounded))
    }
}

extension View {
    func outdoorFont(_ base: CGFloat, weight: Font.Weight = .bold) -> some View {
        modifier(OutdoorFont(base: base, weight: weight))
    }
}

extension EnvironmentValues {
    var fieldPalette: FieldPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
