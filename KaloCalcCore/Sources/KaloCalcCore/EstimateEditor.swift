import Foundation

/// A number as it is shown in an editable field: no trailing ".0", otherwise one decimal.
public func shownNumber(_ d: Double) -> String {
    d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(format: "%.1f", d)
}

/// What the user ends up adding after correcting a recognized dish.
public struct EstimateResult: Equatable {
    public let name: String
    public let grams: Double
    public let kcal: Int
    public let proteinG: Double
    public let carbsG: Double
    public let fatG: Double
    public let ingredients: [Ingredient]
}

/// The state behind "Edit before adding". Changing the grams rescales calories and macros from the original estimate;
/// ingredients can be changed, removed or added, and the dish is re-summed from them. The fields can then be adjusted by hand.
public struct EstimateEditor: Equatable {
    public let estimate: FoodEstimate
    public var name: String
    public var grams: String
    public var kcal: String
    public var protein: String
    public var carbs: String
    public var fat: String
    /// The ingredients at their original weights, with the grams as typed beside them.
    public private(set) var items: [Ingredient]
    public private(set) var ingredientGrams: [String]

    public init(_ e: FoodEstimate) {
        estimate = e
        name = e.name
        grams = String(roundHalfUp(e.grams))
        kcal = String(roundHalfUp(e.kcal))
        protein = shownNumber(e.proteinG)
        carbs = shownNumber(e.carbsG)
        fat = shownNumber(e.fatG)
        items = e.ingredients
        ingredientGrams = e.ingredients.map { String(roundHalfUp($0.grams)) }
    }

    public mutating func changeGrams(_ text: String) {
        grams = text
        guard let g = parseDecimal(text), g > 0 else { return }
        let f = g / estimate.grams
        kcal = String(roundHalfUp(estimate.kcal * f))
        protein = shownNumber(estimate.proteinG * f)
        carbs = shownNumber(estimate.carbsG * f)
        fat = shownNumber(estimate.fatG * f)
    }

    public mutating func changeIngredientGrams(_ index: Int, _ text: String) {
        guard ingredientGrams.indices.contains(index) else { return }
        ingredientGrams[index] = text
        resum()
    }

    public mutating func removeIngredient(_ index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        ingredientGrams.remove(at: index)
        resum()
    }

    public mutating func addIngredient(_ ingredient: Ingredient) {
        items.append(ingredient)
        ingredientGrams.append(shownNumber(ingredient.grams))
        resum()
    }

    private func scaledIngredients() -> [Ingredient] {
        zip(items, ingredientGrams).map { ing, text in ing.scaled(to: parseDecimal(text).flatMap { $0 > 0 ? $0 : nil } ?? 0) }
    }

    /// Totals follow the ingredients; with none left the totals stay as they were, to be typed by hand.
    private mutating func resum() {
        let scaled = scaledIngredients()
        let total = scaled.reduce(0) { $0 + $1.grams }
        if total <= 0 { return }
        grams = String(roundHalfUp(total))
        kcal = String(roundHalfUp(scaled.reduce(0) { $0 + $1.kcal }))
        protein = shownNumber(scaled.reduce(0) { $0 + $1.proteinG })
        carbs = shownNumber(scaled.reduce(0) { $0 + $1.carbsG })
        fat = shownNumber(scaled.reduce(0) { $0 + $1.fatG })
    }

    /// The ingredients as the fields now show them, rescaled to the final total when it was typed over by hand.
    private func currentIngredients(totalGrams: Double) -> [Ingredient] {
        let scaled = scaledIngredients().filter { $0.grams > 0 }
        let sum = scaled.reduce(0) { $0 + $1.grams }
        return sum <= 0 || abs(sum - totalGrams) < 0.5 ? scaled : scaled.map { $0.scaled(to: $0.grams * totalGrams / sum) }
    }

    /// The result to add, or nil while the name is empty, the calories aren't a whole number of at least 0,
    /// or a macro is filled in but isn't a number.
    public var result: EstimateResult? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let k = Int(kcal), k >= 0 else { return nil }
        func macro(_ s: String) -> Double? {
            s.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : parseDecimal(s)
        }
        guard let p = macro(protein), let c = macro(carbs), let f = macro(fat) else { return nil }
        let g = parseDecimal(grams).flatMap { $0 > 0 ? $0 : nil } ?? estimate.grams
        return EstimateResult(name: trimmed, grams: g, kcal: k, proteinG: p, carbsG: c, fatG: f, ingredients: currentIngredients(totalGrams: g))
    }
}
