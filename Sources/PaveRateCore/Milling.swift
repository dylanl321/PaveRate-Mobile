import Foundation

public struct MillingResult: Equatable, Sendable {
    public var squareYards: Double
    public var cubicYards: Double
    public var tons: Double
    public var truckloads: Double
    /// How far one truck of millings reaches at this depth and width.
    public var feetPerTruck: Double

    public init(squareYards: Double, cubicYards: Double, tons: Double, truckloads: Double, feetPerTruck: Double) {
        self.squareYards = squareYards
        self.cubicYards = cubicYards
        self.tons = tons
        self.truckloads = truckloads
        self.feetPerTruck = feetPerTruck
    }
}

/// Milling quantity. Density is a field estimate in tons per cubic yard, not a lab number.
public enum MillingCalculator {
    /// About 110 lbs per square yard per inch, close to the paving rule of thumb.
    public static let defaultDensityTonsPerCubicYard = 2.0

    public static func calculate(
        lengthFt: Double,
        widthFt: Double,
        depthIn: Double,
        densityTonsPerCubicYard: Double,
        truckTons: Double
    ) -> MillingResult? {
        guard lengthFt > 0, widthFt > 0, depthIn > 0, densityTonsPerCubicYard > 0 else { return nil }
        let squareYards = (lengthFt * widthFt) / 9
        let cubicYards = (lengthFt * widthFt * (depthIn / 12)) / 27
        let tons = cubicYards * densityTonsPerCubicYard
        let truckloads = truckTons > 0 ? tons / truckTons : 0
        let feetPerTruck = tons > 0 && truckTons > 0 ? lengthFt * (truckTons / tons) : 0
        return MillingResult(
            squareYards: squareYards,
            cubicYards: cubicYards,
            tons: tons,
            truckloads: truckloads,
            feetPerTruck: feetPerTruck
        )
    }
}
