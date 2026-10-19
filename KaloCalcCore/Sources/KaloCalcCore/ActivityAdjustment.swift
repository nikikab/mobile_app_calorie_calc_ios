import Foundation

/// Differences up to this share of the expected activity are treated as normal for the day.
public let activityToleranceShare = 0.25
/// ...but the allowed difference is never smaller than this many kcal.
public let activityToleranceMinKcal = 100.0

/// The activity calories already built into the daily norm: what the activity factor adds on top of the resting BMR.
public func expectedActiveKcal(_ p: Profile) -> Double { Double(calculate(p).bmr) * (p.activity.factor - 1) }

/// How many kcal to add to (or take off) the day's target, given the active calories `actual` the phone or watch
/// recorded against what the norm `expected`. A difference inside the tolerance band changes nothing; beyond it only
/// the part outside the band counts. A day that isn't over yet only ever raises the target. No reading changes nothing.
public func activityAdjustment(expected: Double, actual: Double?, dayFinished: Bool) -> Int {
    guard let actual, expected > 0 else { return 0 }
    let tolerance = max(expected * activityToleranceShare, activityToleranceMinKcal)
    let diff = actual - expected
    let adjustment: Double
    if diff > tolerance { adjustment = diff - tolerance }
    else if diff < -tolerance { adjustment = diff + tolerance }
    else { adjustment = 0 }
    if !dayFinished && adjustment < 0 { return 0 }
    return roundHalfUp(adjustment)
}

/// `targets` moved by `adjustment` kcal, with the macros scaled along. Lowering never takes the target below the
/// resting `bmr` (nor raises one that was already below it).
public func applyActivityAdjustment(_ targets: DayTargets, bmr: Int, adjustment: Int) -> DayTargets {
    if adjustment == 0 { return targets }
    let moved = targets.kcal + adjustment
    let newKcal = adjustment < 0 ? max(moved, min(targets.kcal, bmr)) : moved
    return newKcal == targets.kcal ? targets : targets.withKcal(newKcal)
}
