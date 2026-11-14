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
    /// Heavy rounded type for direct sun. Only Glare turns it on; the other modes use lighter weights.
    var heavyType: Bool = false

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

    /// Daylight: warm stone with charcoal text and hairline borders. Glare is the max-contrast mode.
    static let sunlight = FieldPalette(
        background: Color(red: 0.937, green: 0.929, blue: 0.910),
        surface: Color(red: 0.980, green: 0.976, blue: 0.965),
        surfaceAlt: Color(red: 0.953, green: 0.945, blue: 0.925),
        border: Color(red: 0.871, green: 0.855, blue: 0.824),
        text: Color(red: 0.141, green: 0.157, blue: 0.176),
        muted: Color(red: 0.361, green: 0.388, blue: 0.420),
        accent: Color(red: 0.878, green: 0.635, blue: 0.118),
        accentText: Color(red: 0.165, green: 0.122, blue: 0.016),
        good: Color(red: 0.118, green: 0.416, blue: 0.231),
        warn: Color(red: 0.529, green: 0.318, blue: 0.043),
        bad: Color(red: 0.659, green: 0.227, blue: 0.196),
        onGood: .white,
        onWarn: .white,
        onBad: .white,
        borderWidth: 1,
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
        layout: .fieldGlare,
        heavyType: true
    )

    /// Dusk: soft slate with off-white text, not white on black.
    static let night = FieldPalette(
        background: Color(red: 0.110, green: 0.129, blue: 0.153),
        surface: Color(red: 0.145, green: 0.169, blue: 0.196),
        surfaceAlt: Color(red: 0.173, green: 0.200, blue: 0.231),
        border: Color(red: 0.208, green: 0.239, blue: 0.275),
        text: Color(red: 0.894, green: 0.906, blue: 0.918),
        muted: Color(red: 0.604, green: 0.643, blue: 0.682),
        accent: Color(red: 0.890, green: 0.675, blue: 0.227),
        accentText: Color(red: 0.110, green: 0.086, blue: 0.024),
        good: Color(red: 0.361, green: 0.769, blue: 0.541),
        warn: Color(red: 0.910, green: 0.647, blue: 0.290),
        bad: Color(red: 0.878, green: 0.408, blue: 0.373),
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
        content.font(palette.font(size: size, weight: weight, base: base))
    }
}

extension FieldPalette {
    /// Glare keeps the requested weight in rounded type. The softer modes cap bold at
    /// semibold for big numbers and titles, and use medium for everything smaller.
    func font(size: CGFloat, weight: Font.Weight, base: CGFloat) -> Font {
        if heavyType {
            return .system(size: size, weight: weight, design: .rounded)
        }
        return .system(size: size, weight: softened(weight, base: base))
    }

    func softened(_ weight: Font.Weight, base: CGFloat) -> Font.Weight {
        switch weight {
        case .black, .heavy, .bold:
            return base >= 28 ? .semibold : .medium
        case .semibold:
            return .medium
        default:
            return weight
        }
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
