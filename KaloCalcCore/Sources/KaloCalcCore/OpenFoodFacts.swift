import Foundation

/// Nutrition values are per 100 g, as Open Food Facts reports them.
public struct Product: Equatable {
    public var name: String
    public var brand: String
    public var kcal100: Double
    public var protein100: Double
    public var carbs100: Double
    public var fat100: Double

    public init(name: String, brand: String, kcal100: Double, protein100: Double, carbs100: Double, fat100: Double) {
        self.name = name; self.brand = brand; self.kcal100 = kcal100
        self.protein100 = protein100; self.carbs100 = carbs100; self.fat100 = fat100
    }
}

func parseProduct(_ p: JSONObject) -> Product? {
    guard let n = p["nutriments"] as? JSONObject, n["energy-kcal_100g"] != nil else { return nil }
    let name = optString(p, "product_name").trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty { return nil }
    return Product(name: name, brand: firstBrand(p), kcal100: optDouble(n, "energy-kcal_100g"),
                   protein100: optDouble(n, "proteins_100g"), carbs100: optDouble(n, "carbohydrates_100g"),
                   fat100: optDouble(n, "fat_100g"))
}

// The product API returns "brands" as a comma-separated string, the search API as an array.
private func firstBrand(_ p: JSONObject) -> String {
    if let arr = p["brands"] as? [Any] {
        return ((arr.first as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let s = optString(p, "brands")
    return String(s.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Parses a search-a-licious response (results are under "hits").
public func parseSearch(_ json: String) throws -> [Product] {
    guard let root = try parseJSON(json) as? JSONObject, let hits = root["hits"] as? [Any] else { return [] }
    return hits.compactMap { ($0 as? JSONObject).flatMap(parseProduct) }
}

/// Returns nil when the barcode is unknown or the product has no usable nutrition data.
public func parseBarcode(_ json: String) throws -> Product? {
    guard let root = try parseJSON(json) as? JSONObject, (root["status"] as? NSNumber)?.intValue == 1 else { return nil }
    return (root["product"] as? JSONObject).flatMap(parseProduct)
}
