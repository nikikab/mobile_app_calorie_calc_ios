import Foundation

public let maxPlanName = 40
public let maxPlanKcal = 10_000
public let maxPlanGrams = 1_000

/// A saved goal with its own calories and macro grams, entered freely (they don't have to match each other).
/// `baseKcal` is the profile's calorie target when the goal was saved; the goal is scaled by the ratio of today's
/// target to it, so when the weight changes every value changes in the same proportion.
public struct GoalPlan: Equatable, Codable {
    public var id: Int64
    public var name: String
    public var kcal: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var baseKcal: Int

    public init(id: Int64 = 0, name: String, kcal: Int, proteinG: Int, carbsG: Int, fatG: Int, baseKcal: Int) {
        self.id = id; self.name = name; self.kcal = kcal; self.proteinG = proteinG
        self.carbsG = carbsG; self.fatG = fatG; self.baseKcal = baseKcal
    }

    /// The goal as it stands for a day whose profile target is `currentTarget`.
    public func scaled(to currentTarget: Int) -> DayTargets {
        let f = baseKcal > 0 ? Double(currentTarget) / Double(baseKcal) : 1.0
        func scale(_ v: Int) -> Int { roundHalfUp(Double(v) * f) }
        return DayTargets(scale(kcal), MacroGoals(scale(proteinG), scale(carbsG), scale(fatG)))
    }

    /// A goal that can be saved and trusted: named, with positive calories and sane gram amounts.
    public var isUsable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.utf16.count <= maxPlanName
            && (1...maxPlanKcal).contains(kcal)
            && [proteinG, carbsG, fatG].allSatisfy { (0...maxPlanGrams).contains($0) } && baseKcal > 0
    }
}

/// The selected saved goal scaled to today's profile, or the profile's own calories and default split when none is selected.
public func resolveTargets(profile: Profile, plans: [GoalPlan], activeId: Int64) -> DayTargets {
    let target = calculate(profile).target
    if let plan = plans.first(where: { $0.id == activeId }) { return plan.scaled(to: target) }
    return DayTargets(target, macroGoals(targetKcal: target, split: baseSplit(insulinResistance: profile.insulinResistance)))
}
