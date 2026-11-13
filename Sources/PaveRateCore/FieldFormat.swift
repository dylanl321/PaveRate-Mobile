import Foundation

/// Number text that matches the web app's `toFixed` / `Math.round` for the
/// positive field values these calculators produce.
public enum FieldFormat {
    /// ECMAScript `Math.round`: floor(x + 0.5), including negatives.
    public static func jsRound(_ value: Double) -> Double {
        if value.isNaN || value.isInfinite { return value }
        return (value + 0.5).rounded(.down)
    }

    /// ECMAScript `Number#toFixed` for values that are exact in binary, or
    /// close enough that rounding through `Math.round` agrees with V8.
    public static func fixed(_ value: Double, digits: Int) -> String {
        let places = max(0, digits)
        let factor = pow(10, Double(places))
        let rounded = jsRound(value * factor) / factor
        return String(format: "%.\(places)f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    /// JavaScript's default number-to-string for the magnitudes used here.
    public static func jsNumber(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value.rounded()))
        }
        var text = fixed(value, digits: 6)
        while text.contains(".") && text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    public static func groupedRound(_ value: Double) -> String {
        let rounded = jsRound(value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: rounded)) ?? fixed(rounded, digits: 0)
    }
}
