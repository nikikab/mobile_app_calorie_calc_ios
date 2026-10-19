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

    /// Negative when the day is over the target.
    public var remainingKcal: Int { targetKcal - kcal }
    public var kcalProgress: Double { progress(Double(kcal), Double(targetKcal)) }
    public var proteinProgress: Double { progress(proteinG, Double(goals.proteinG)) }
    public var carbsProgress: Double { progress(carbsG, Double(goals.carbsG)) }
    public var fatProgress: Double { progress(fatG, Double(goals.fatG)) }

    private func progress(_ value: Double, _ goal: Double) -> Double { goal > 0 ? min(max(value / goal, 0), 1) : 0 }
}

/// The selected saved goal (or the profile's own split) for the day; a calorie target typed in for that day replaces
/// the calories and the macros follow in proportion.
public func summarizeDay(entries: [FoodEntry], profile: Profile, plans: [GoalPlan], activePlanId: Int64,
                         dayTarget: DayTarget?) -> DaySummary {
    let usual = resolveTargets(profile: profile, plans: plans, activeId: activePlanId)
    let targets = dayTarget.map { usual.withKcal($0.kcal) } ?? usual
    return DaySummary(
        targetKcal: targets.kcal, goals: targets.macros, defaultKcal: usual.kcal, isCustomTarget: dayTarget != nil,
        kcal: entries.reduce(0) { $0 + $1.kcal }, proteinG: entries.reduce(0) { $0 + $1.proteinG },
        carbsG: entries.reduce(0) { $0 + $1.carbsG }, fatG: entries.reduce(0) { $0 + $1.fatG })
}
