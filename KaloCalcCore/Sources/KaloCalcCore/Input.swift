import Foundation

/// A number typed by the user; a comma works as the decimal separator.
public func parseDecimal(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
}

/// A gram value as the user would type it: no trailing ".0".
public func gramsText(_ v: Double) -> String {
    v == v.rounded() && abs(v) < 1e9 ? String(Int(v)) : String(v)
}

/// The profile typed into the calculator, or nil unless every field is in a sensible range.
public func parseProfileInput(sex: Sex, age: String, height: String, weight: String, activity: ActivityLevel,
                              goal: Goal, insulinResistance: Bool) -> Profile? {
    guard let a = Int(age), let h = Int(height), let w = parseDecimal(weight),
          (10...120).contains(a), (100...250).contains(h), (30.0...300.0).contains(w) else { return nil }
    return Profile(sex: sex, age: a, heightCm: h, weightKg: w, activity: activity, goal: goal, insulinResistance: insulinResistance)
}

/// What the add/edit dialog produces.
public struct EntryValues: Equatable {
    public var meal: Meal
    public var name: String
    /// 0 when unknown.
    public var grams: Double
    public var kcal: Int
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(meal: Meal, name: String, grams: Double, kcal: Int, proteinG: Double, carbsG: Double, fatG: Double) {
        self.meal = meal; self.name = name; self.grams = grams; self.kcal = kcal
        self.proteinG = proteinG; self.carbsG = carbsG; self.fatG = fatG
    }
}

/// The dialog's text fields as values, or nil when the name is empty, the calories aren't a whole number of at least 0,
/// or a macro is filled in but isn't a number. Empty macros count as 0.
public func parseEntryInput(meal: Meal, name: String, grams: String, kcal: String, protein: String, carbs: String,
                            fat: String) -> EntryValues? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let k = Int(kcal), k >= 0 else { return nil }
    func macro(_ s: String) -> Double?? {
        s.trimmingCharacters(in: .whitespaces).isEmpty ? .some(0) : parseDecimal(s).map { .some($0) }
    }
    guard case let .some(.some(p)) = macro(protein), case let .some(.some(c)) = macro(carbs),
          case let .some(.some(f)) = macro(fat) else { return nil }
    let g = parseDecimal(grams).flatMap { $0 > 0 ? $0 : nil } ?? 0
    return EntryValues(meal: meal, name: trimmed, grams: g, kcal: k, proteinG: p, carbsG: c, fatG: f)
}

extension GoalPlan {
    /// The goal as it stands today, rebased on today's calorie target so that saving it starts scaling from here.
    public func rebased(onTarget currentTarget: Int) -> GoalPlan {
        let t = scaled(to: currentTarget)
        var p = self
        p.kcal = t.kcal; p.proteinG = t.macros.proteinG; p.carbsG = t.macros.carbsG; p.fatG = t.macros.fatG
        p.baseKcal = currentTarget
        return p
    }
}
