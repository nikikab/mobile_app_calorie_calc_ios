import Foundation

/// Household measures an ingredient can be entered in. `gramsPer` is nil for pieces, whose weight depends on the food.
public enum MeasureUnit: CaseIterable {
    case g, ml, tbsp, tsp, cup, piece

    public var gramsPer: Double? {
        switch self {
        case .g, .ml: return 1
        case .tbsp: return 15
        case .tsp: return 5
        case .cup: return 240
        case .piece: return nil
        }
    }
}

/// An amount as people write it: "50", "1,5", "1/2" or "1 1/2". Nil when it isn't one.
public func parseAmount(_ text: String) -> Double? {
    let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        .split(whereSeparator: { $0.isWhitespace }).map(String.init)
    if parts.isEmpty || parts.count > 2 { return nil }
    var total = 0.0
    for (i, part) in parts.enumerated() {
        let fraction = part.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let value: Double?
        switch fraction.count {
        case 1:
            value = Double(part)
        case 2:
            // A fraction is only allowed last, so "1/2 1" is not an amount.
            if let n = Double(fraction[0]), let d = Double(fraction[1]), d != 0, i == parts.count - 1 { value = n / d } else { value = nil }
        default:
            value = nil
        }
        guard let v = value else { return nil }
        total += v
    }
    return total
}

/// Grams for `amount` of `unit`; `pieceGrams` is the weight of one piece. Nil when something is missing.
public func gramsFor(_ amount: Double?, _ unit: MeasureUnit, pieceGrams: Double?) -> Double? {
    guard let per = unit.gramsPer ?? pieceGrams, let amount else { return nil }
    return amount * per
}
