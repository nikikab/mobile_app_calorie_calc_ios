import Foundation

/// Kotlin's `roundToInt` / `Math.round`: halves go up, also for negatives (-2.5 -> -2).
func roundHalfUp(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

public enum Sex: String, Codable, CaseIterable { case male = "MALE", female = "FEMALE" }

public enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "SEDENTARY", light = "LIGHT", moderate = "MODERATE", high = "HIGH", extreme = "EXTREME"

    public var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .high: return 1.725
        case .extreme: return 1.9
        }
    }
}

public enum Goal: String, Codable, CaseIterable {
    case lose = "LOSE", maintain = "MAINTAIN", gain = "GAIN"

    public var deltaKcal: Int {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 300
        }
    }
}

public struct Profile: Equatable, Codable {
    public var sex: Sex
    public var age: Int
    public var heightCm: Int
    public var weightKg: Double
    public var activity: ActivityLevel
    public var goal: Goal
    /// Switches the macro split and adds fibre and sugar guidance; calories are worked out the same way.
    public var insulinResistance: Bool

    public init(sex: Sex = .male, age: Int = 30, heightCm: Int = 175, weightKg: Double = 75.0,
                activity: ActivityLevel = .light, goal: Goal = .maintain, insulinResistance: Bool = false) {
        self.sex = sex; self.age = age; self.heightCm = heightCm; self.weightKg = weightKg
        self.activity = activity; self.goal = goal; self.insulinResistance = insulinResistance
    }
}

public struct CalorieResult: Equatable {
    public let bmr: Int, tdee: Int, target: Int
}

/// Mifflin-St Jeor BMR, scaled by activity (TDEE) and adjusted by goal.
public func calculate(_ p: Profile) -> CalorieResult {
    let base = 10 * p.weightKg + 6.25 * Double(p.heightCm) - 5 * Double(p.age)
    let bmr = base + (p.sex == .male ? 5 : -161)
    let tdee = bmr * p.activity.factor
    return CalorieResult(bmr: roundHalfUp(bmr), tdee: roundHalfUp(tdee),
                         target: roundHalfUp(tdee + Double(p.goal.deltaKcal)))
}

public struct MacroGoals: Equatable {
    public let proteinG: Int, carbsG: Int, fatG: Int
    public init(_ proteinG: Int, _ carbsG: Int, _ fatG: Int) {
        self.proteinG = proteinG; self.carbsG = carbsG; self.fatG = fatG
    }
}

/// Share of the calorie target going to protein, carbs and fat, in whole percent.
public struct MacroSplit: Equatable {
    public let proteinPct: Int, carbsPct: Int, fatPct: Int
    public init(proteinPct: Int, carbsPct: Int, fatPct: Int) {
        self.proteinPct = proteinPct; self.carbsPct = carbsPct; self.fatPct = fatPct
    }
}

/// The calories and macro grams a day is measured against.
public struct DayTargets: Equatable {
    public let kcal: Int
    public let macros: MacroGoals
    public init(_ kcal: Int, _ macros: MacroGoals) { self.kcal = kcal; self.macros = macros }

    /// The same targets with the calories set to `newKcal` and the macros scaled in the same proportion.
    public func withKcal(_ newKcal: Int) -> DayTargets {
        if kcal <= 0 { return DayTargets(newKcal, macros) }
        let f = Double(newKcal) / Double(kcal)
        return DayTargets(newKcal, MacroGoals(roundHalfUp(Double(macros.proteinG) * f),
                                              roundHalfUp(Double(macros.carbsG) * f),
                                              roundHalfUp(Double(macros.fatG) * f)))
    }
}

public let standardSplit = MacroSplit(proteinPct: 30, carbsPct: 40, fatPct: 30)

/// Moderate-carbohydrate split often suggested for insulin resistance: carbs 5 points lower than the standard split,
/// moved to fat. A general guideline picked here, not a clinical formula.
public let insulinResistanceSplit = MacroSplit(proteinPct: 30, carbsPct: 35, fatPct: 35)

/// The split a profile uses when no saved goal is selected.
public func baseSplit(insulinResistance: Bool) -> MacroSplit { insulinResistance ? insulinResistanceSplit : standardSplit }

/// Turns the calorie target into grams by `split` (4, 4 and 9 kcal per gram).
public func macroGoals(targetKcal: Int, split: MacroSplit) -> MacroGoals {
    let k = Double(targetKcal)
    return MacroGoals(roundHalfUp(k * Double(split.proteinPct) / 100.0 / 4),
                      roundHalfUp(k * Double(split.carbsPct) / 100.0 / 4),
                      roundHalfUp(k * Double(split.fatPct) / 100.0 / 9))
}

public func macroGoals(targetKcal: Int, insulinResistance: Bool = false) -> MacroGoals {
    macroGoals(targetKcal: targetKcal, split: baseSplit(insulinResistance: insulinResistance))
}

/// Guidance only: the app doesn't track fibre or sugar, so these are shown on the goal screen and not in the diary.
public struct IntakeLimits: Equatable {
    public let fiberMinG: Int, freeSugarMaxG: Int
}

/// Fibre: 14 g per 1000 kcal, at least 25 g. Free sugars: at most 5% of calories (4 kcal per gram).
public func intakeLimits(targetKcal: Int) -> IntakeLimits {
    IntakeLimits(fiberMinG: max(25, roundHalfUp(Double(targetKcal) * 14 / 1000.0)),
                 freeSugarMaxG: roundHalfUp(Double(targetKcal) * 0.05 / 4))
}
