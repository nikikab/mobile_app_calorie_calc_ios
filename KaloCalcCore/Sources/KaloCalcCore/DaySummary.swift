import Foundation

/// The numbers the diary shows for one day: what was eaten, and the targets in force for that day.
public struct DaySummary: Equatable {
    public let targetKcal: Int
    public let goals: MacroGoals
    /// The usual target for this day, which `targetKcal` differs from when `isCustomTarget`.
    public let defaultKcal: Int
    public let isCustomTarget: Bool
    public let kcal: Int
    public let proteinG: Double
    public let carbsG: Double
    public let fatG: Double
    /// Set when burned calories moved the target (it is then already included in `targetKcal`).
    public let activity: ActivityNote?

    /// Negative when the day is over the target.
    public var remainingKcal: Int { targetKcal - kcal }
    public var kcalProgress: Double { progress(Double(kcal), Double(targetKcal)) }
    public var proteinProgress: Double { progress(proteinG, Double(goals.proteinG)) }
    public var carbsProgress: Double { progress(carbsG, Double(goals.carbsG)) }
    public var fatProgress: Double { progress(fatG, Double(goals.fatG)) }

    private func progress(_ value: Double, _ goal: Double) -> Double { goal > 0 ? min(max(value / goal, 0), 1) : 0 }
}

/// How far the active calories read from Health moved the day's target: `kcal` is the change that was applied,
/// `actual` what was burned and `expected` what the usual target already assumes.
public struct ActivityNote: Equatable {
    public let kcal: Int, actual: Int, expected: Int
    public init(kcal: Int, actual: Int, expected: Int) { self.kcal = kcal; self.actual = actual; self.expected = expected }
}

/// The selected saved goal (or the profile's own split) for the day; a calorie target typed in for that day replaces
/// the calories and the macros follow in proportion. With `activeKcal` (the day's burned calories from Health) the usual
/// target moves by `activityAdjustment`; a target typed in for the day is left alone.
public func summarizeDay(entries: [FoodEntry], profile: Profile, plans: [GoalPlan], activePlanId: Int64,
                         dayTarget: DayTarget?, activeKcal: Double? = nil, dayFinished: Bool = false) -> DaySummary {
    let usual = resolveTargets(profile: profile, plans: plans, activeId: activePlanId)
    var targets = dayTarget.map { usual.withKcal($0.kcal) } ?? usual
    var note: ActivityNote?
    if dayTarget == nil, let activeKcal {
        let expected = expectedActiveKcal(profile)
        let adjustment = activityAdjustment(expected: expected, actual: activeKcal, dayFinished: dayFinished)
        let moved = applyActivityAdjustment(usual, bmr: calculate(profile).bmr, adjustment: adjustment)
        let applied = moved.kcal - usual.kcal
        if applied != 0 {
            targets = moved
            note = ActivityNote(kcal: applied, actual: roundHalfUp(activeKcal), expected: roundHalfUp(expected))
        }
    }
    return DaySummary(
        targetKcal: targets.kcal, goals: targets.macros, defaultKcal: usual.kcal, isCustomTarget: dayTarget != nil,
        kcal: entries.reduce(0) { $0 + $1.kcal }, proteinG: entries.reduce(0) { $0 + $1.proteinG },
        carbsG: entries.reduce(0) { $0 + $1.carbsG }, fatG: entries.reduce(0) { $0 + $1.fatG }, activity: note)
}
