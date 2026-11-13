import Foundation

/// CALC.SQ_YARDS — area in square yards.
public func squareYards(_ lengthFt: Double, _ widthFt: Double) -> Double {
    (lengthFt * widthFt) / PaveRateConfig.constant("CONST.SF_PER_SY")
}

/// CALC.SPREAD_PLACED — placed spread rate (lbs/SY).
/// Retention is subtracted in tons before converting to pounds, and only on the first pass.
/// A missing machine id is `none` (0 tons), matching `machineId ?? 'none'`.
public func spreadRatePlaced(
    tons: Double,
    lengthFt: Double,
    widthFt: Double,
    machineId: String = "none",
    firstPass: Bool = false
) -> Double {
    let retain = firstPass ? PaveRateConfig.machine(machineId).retainTons : 0
    let pounds = (tons - retain) * PaveRateConfig.constant("CONST.LB_PER_TON")
    let sy = squareYards(lengthFt, widthFt)
    return sy > 0 ? pounds / sy : 0
}

/// CALC.SPREAD_THICK — quick spread rate from thickness (inches × 110).
public func spreadRateFromThickness(_ thicknessIn: Double) -> Double {
    thicknessIn * PaveRateConfig.constant("CONST.THICK_MULT")
}

/// Shared tons → feet engine.
/// Feet = Tons × 2000 × 9 / (Width × Rate).
public func feetFromTons(_ tons: Double, widthFt: Double, rateLbsSy: Double) -> Double {
    let denom = widthFt * rateLbsSy
    if denom <= 0 { return 0 }
    return (tons * PaveRateConfig.constant("CONST.LB_PER_TON") * PaveRateConfig.constant("CONST.SF_PER_SY")) / denom
}

/// CALC.ACTUAL_RATE — inverse of `feetFromTons`.
public func actualSpreadRate(tons: Double, distanceFt: Double, widthFt: Double) -> Double {
    let denom = widthFt * distanceFt
    if denom <= 0 { return 0 }
    return (tons * PaveRateConfig.constant("CONST.LB_PER_TON") * PaveRateConfig.constant("CONST.SF_PER_SY")) / denom
}

/// CALC.REMAINING_DIST — feet left from loads remaining.
public func feetFromLoads(
    loads: Double,
    tonsPerLoad: Double? = nil,
    widthFt: Double,
    rateLbsSy: Double
) -> Double {
    let perLoad = tonsPerLoad ?? PaveRateConfig.constant("CONST.TRUCK_LOAD")
    return feetFromTons(loads * perLoad, widthFt: widthFt, rateLbsSy: rateLbsSy)
}

/// CALC.FEET_TODAY — feet left from ordered minus placed.
public func feetFromOrderedMinusPlaced(
    tonsOrdered: Double,
    tonsPlaced: Double,
    widthFt: Double,
    rateLbsSy: Double
) -> Double {
    feetFromTons(tonsOrdered - tonsPlaced, widthFt: widthFt, rateLbsSy: rateLbsSy)
}

/// CALC.TACK_GALLONS — gallons of tack for an area at a shot rate (gal/SY).
public func tackGallons(_ lengthFt: Double, _ widthFt: Double, _ shotRateGalSy: Double) -> Double {
    squareYards(lengthFt, widthFt) * shotRateGalSy
}

/// CALC.TONNAGE — tons to order, with optional waste percent.
public func tonnageToOrder(
    lengthFt: Double,
    widthFt: Double,
    rateLbsSy: Double,
    wastePct: Double = 0
) -> Double {
    let base = (squareYards(lengthFt, widthFt) * rateLbsSy) / PaveRateConfig.constant("CONST.LB_PER_TON")
    return base * (1 + wastePct / 100)
}

/// CALC.STICK — loose height behind the screed.
public func stickCheck(_ thicknessIn: Double) -> Double {
    thicknessIn * PaveRateConfig.constant("CONST.STICK_FACTOR")
}

/// Tons that place `rateLbsSy` over the area. Rounded to 0.01 ton the way the web "Snap to spec" button does.
public func tonsToMatchRate(lengthFt: Double, widthFt: Double, rateLbsSy: Double) -> Double {
    let tons = (rateLbsSy * squareYards(lengthFt, widthFt)) / PaveRateConfig.constant("CONST.LB_PER_TON")
    return FieldFormat.jsRound(tons * 100) / 100
}
