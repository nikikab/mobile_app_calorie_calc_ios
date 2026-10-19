import Foundation

public let maxFavoriteName = 80

/// A dish the user saved to add again later; nutrition values are for the whole portion of `grams`.
public struct Favorite: Equatable, Codable {
    public var id: Int64
    public var name: String
    public var grams: Double
    public var kcal: Int
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    /// The dish's ingredients as a JSON array (see `ingredientsToJson`); empty when there are none.
    public var ingredients: String

    public init(id: Int64 = 0, name: String, grams: Double, kcal: Int, proteinG: Double, carbsG: Double, fatG: Double,
                ingredients: String = "") {
        self.id = id; self.name = name; self.grams = grams; self.kcal = kcal
        self.proteinG = proteinG; self.carbsG = carbsG; self.fatG = fatG; self.ingredients = ingredients
    }

    public var isUsable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.utf16.count <= maxFavoriteName
            && grams > 0 && (0...maxPlanKcal).contains(kcal) && [proteinG, carbsG, fatG].allSatisfy { $0 >= 0 }
    }

    public func toEstimate() -> FoodEstimate {
        FoodEstimate(name: name, grams: grams, kcal: Double(kcal), proteinG: proteinG, carbsG: carbsG, fatG: fatG,
                     ingredients: ingredientsFromJson(ingredients))
    }
}

extension FoodEstimate {
    public func toFavorite() -> Favorite {
        Favorite(name: name.trimmingCharacters(in: .whitespacesAndNewlines), grams: grams, kcal: roundHalfUp(kcal),
                 proteinG: proteinG, carbsG: carbsG, fatG: fatG, ingredients: ingredientsToJson(ingredients))
    }
}

public func ingredientsToJson(_ list: [Ingredient]) -> String {
    if list.isEmpty { return "" }
    let array: [[String: Any]] = list.map {
        ["name": $0.name, "grams": $0.grams, "kcal": $0.kcal,
         "protein_g": $0.proteinG, "carbs_g": $0.carbsG, "fat_g": $0.fatG]
    }
    guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys]) else { return "" }
    return String(decoding: data, as: UTF8.self)
}

/// Tolerant on purpose: a damaged ingredient list just means the favorite has no ingredients.
public func ingredientsFromJson(_ json: String) -> [Ingredient] {
    if json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    guard let arr = (try? parseJSON(json)) as? [Any] else { return [] }
    return arr.compactMap { item -> Ingredient? in
        guard let o = item as? JSONObject else { return nil }
        let name = optString(o, "name").trimmingCharacters(in: .whitespacesAndNewlines)
        let grams = optDouble(o, "grams")
        if name.isEmpty || grams <= 0 { return nil }
        return Ingredient(name: name, grams: grams, kcal: optDouble(o, "kcal"), proteinG: optDouble(o, "protein_g"),
                          carbsG: optDouble(o, "carbs_g"), fatG: optDouble(o, "fat_g"))
    }
}
