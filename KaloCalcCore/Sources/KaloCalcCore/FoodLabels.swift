import Foundation

public struct FoodLabel: Equatable {
    public let text: String
    public let confidence: Float
    public init(text: String, confidence: Float) { self.text = text; self.confidence = confidence }
}

// Labels the on-device model gives to almost any meal photo; useless as search terms.
private let genericLabels: Set<String> = [
    "food", "ingredient", "dish", "cuisine", "recipe", "meal", "tableware", "plate", "dishware",
    "table", "drink", "cup", "bowl", "fork", "spoon", "knife", "cutlery", "kitchen", "produce",
    "staple food", "comfort food", "fast food", "finger food", "junk food", "baked goods", "snack",
    "natural foods", "whole food", "superfood", "leaf vegetable", "serveware", "drinkware",
    // Vision's top-level categories.
    "structure", "indoor", "outdoor", "material", "container", "kitchenware", "cooking", "plant",
]

/// Drops generic labels and keeps the most confident specific ones, best first.
/// Underscores in a label (as Vision writes multi-word names) count as spaces.
public func specificFoodLabels(_ labels: [FoodLabel], max: Int = 5) -> [FoodLabel] {
    let cleaned = labels.map { FoodLabel(text: $0.text.replacingOccurrences(of: "_", with: " "), confidence: $0.confidence) }
    return Array(cleaned.filter { !genericLabels.contains($0.text.lowercased()) }
        .sorted { $0.confidence > $1.confidence }.prefix(max))
}
