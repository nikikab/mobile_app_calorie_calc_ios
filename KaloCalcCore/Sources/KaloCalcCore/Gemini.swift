import Foundation

/// One ingredient of an estimated dish; nutrition values are for the ingredient's own weight.
public struct Ingredient: Equatable {
    public var name: String
    public var grams: Double
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public init(name: String, grams: Double, kcal: Double, proteinG: Double, carbsG: Double, fatG: Double) {
        self.name = name; self.grams = grams; self.kcal = kcal
        self.proteinG = proteinG; self.carbsG = carbsG; self.fatG = fatG
    }

    /// This ingredient as if it weighed `newGrams`; nutrition scales in proportion.
    public func scaled(to newGrams: Double) -> Ingredient {
        let f = grams > 0 ? newGrams / grams : 0
        return Ingredient(name: name, grams: newGrams, kcal: kcal * f, proteinG: proteinG * f, carbsG: carbsG * f, fatG: fatG * f)
    }
}

/// A model's guess for one item in the photo; all nutrition values are for the whole estimated portion.
public struct FoodEstimate: Equatable {
    public var name: String
    public var grams: Double
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var ingredients: [Ingredient]

    public init(name: String, grams: Double, kcal: Double, proteinG: Double, carbsG: Double, fatG: Double,
                ingredients: [Ingredient] = []) {
        self.name = name; self.grams = grams; self.kcal = kcal; self.proteinG = proteinG
        self.carbsG = carbsG; self.fatG = fatG; self.ingredients = ingredients
    }

    /// Per-100 g values, so the normal portion dialog can rescale the guess.
    public func toProduct() -> Product {
        Product(name: name, brand: "Gemini", kcal100: kcal * 100 / grams, protein100: proteinG * 100 / grams,
                carbs100: carbsG * 100 / grams, fat100: fatG * 100 / grams)
    }
}

/// Failures the UI turns into a localized message.
public enum GeminiError: Error, Equatable {
    case noCandidates, empty, garbled, badModel(String)
    /// The model id isn't known to the API (HTTP 404 on a model call).
    case modelMissing(String)
    /// HTTP 429, the free quota is used up.
    case rateLimited
    /// HTTP 500, 502, 503 or 504.
    case overloaded
    case http(code: Int, detail: String?)
}

private func firstText(_ response: String) throws -> (candidate: Bool, part: Bool, text: String?) {
    guard let root = try parseJSON(response) as? JSONObject,
          let candidate = (root["candidates"] as? [Any])?.first as? JSONObject else { return (false, false, nil) }
    guard let part = ((candidate["content"] as? JSONObject)?["parts"] as? [Any])?.first as? JSONObject else { return (true, false, nil) }
    return (true, true, optString(part, "text"))
}

/// Extracts the estimates from a generateContent response; items without a positive weight are dropped.
public func parseEstimates(_ response: String) throws -> [FoodEstimate] {
    let r = try firstText(response)
    if !r.candidate { throw GeminiError.noCandidates }
    guard r.part, let text = r.text else { throw GeminiError.empty }
    guard let arr = (try? parseJSON(text)) as? [Any] else { throw GeminiError.garbled }
    return try arr.compactMap { item in
        guard let o = item as? JSONObject else { throw GeminiError.garbled }
        let grams = optDouble(o, "grams")
        let name = optString(o, "name").trimmingCharacters(in: .whitespacesAndNewlines)
        if grams <= 0 || name.isEmpty { return nil }
        return FoodEstimate(name: name, grams: grams, kcal: optDouble(o, "kcal"), proteinG: optDouble(o, "protein_g"),
                            carbsG: optDouble(o, "carbs_g"), fatG: optDouble(o, "fat_g"),
                            ingredients: parseIngredients(o["ingredients"] as? [Any]))
    }
}

private func parseIngredients(_ arr: [Any]?) -> [Ingredient] {
    (arr ?? []).compactMap { item in
        guard let o = item as? JSONObject else { return nil }
        let grams = optDouble(o, "grams")
        let name = optString(o, "name").trimmingCharacters(in: .whitespacesAndNewlines)
        if grams <= 0 || name.isEmpty { return nil }
        return Ingredient(name: name, grams: grams, kcal: optDouble(o, "kcal"), proteinG: optDouble(o, "protein_g"),
                          carbsG: optDouble(o, "carbs_g"), fatG: optDouble(o, "fat_g"))
    }
}

/// Reads the JSON array of strings a translation call returns; nil when it isn't one array entry per input.
public func parseTranslations(_ response: String, expected: Int) -> [String]? {
    guard let r = try? firstText(response), let text = r.text,
          let arr = (try? parseJSON(text)) as? [Any], arr.count == expected else { return nil }
    return arr.map { (($0 as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Names (without the "models/" prefix) of models that can generate content, from a ListModels response.
public func parseModelNames(_ response: String) throws -> [String] {
    guard let root = try parseJSON(response) as? JSONObject, let models = root["models"] as? [Any] else { return [] }
    return models.compactMap { $0 as? JSONObject }
        .filter { ($0["supportedGenerationMethods"] as? [Any])?.contains { ($0 as? String) == "generateContent" } ?? false }
        .map { optString($0, "name") }
        .map { $0.hasPrefix("models/") ? String($0.dropFirst("models/".count)) : $0 }
}
