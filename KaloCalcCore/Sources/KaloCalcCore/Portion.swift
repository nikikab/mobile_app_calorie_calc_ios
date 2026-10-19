import Foundation

/// A product's nutrition for a portion of some weight.
public struct Portion: Equatable {
    public let kcal: Int
    public let proteinG: Double
    public let carbsG: Double
    public let fatG: Double
}

extension Product {
    /// The values per 100 g scaled to `grams`.
    public func portion(grams: Double) -> Portion {
        let f = grams / 100
        return Portion(kcal: roundHalfUp(kcal100 * f), proteinG: protein100 * f, carbsG: carbs100 * f, fatG: fat100 * f)
    }
}
