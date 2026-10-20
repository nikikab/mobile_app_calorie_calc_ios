import Foundation

/// [kcal] is nil for days with no diary entries, so they show as gaps rather than zero-calorie days.
public struct DayBar: Equatable {
    public let epochDay: Int64
    public let kcal: Int?
    public init(epochDay: Int64, kcal: Int?) { self.epochDay = epochDay; self.kcal = kcal }
}

/// The last `days` days ending on `today`, oldest first.
public func weekBars(endingOn today: Int64, kcalByDay: [Int64: Int], days: Int = 7) -> [DayBar] {
    (0..<days).reversed().map { back in
        let day = today - Int64(back)
        return DayBar(epochDay: day, kcal: kcalByDay[day])
    }
}

/// A body weight typed by the user, accepted between 30 and 300 kg; a comma works as the decimal separator.
public func parseWeightInput(_ text: String) -> Double? {
    parseDecimal(text).flatMap { (30.0...300.0).contains($0) ? $0 : nil }
}

public struct WeightTrend: Equatable {
    public let latest: Double
    /// Latest minus first; nil with a single entry.
    public let change: Double?
    public let count: Int
}

/// `weights` must be sorted oldest first.
public func weightTrend(_ weights: [WeightEntry]) -> WeightTrend? {
    guard let first = weights.first, let last = weights.last else { return nil }
    return WeightTrend(latest: last.kg, change: weights.count > 1 ? last.kg - first.kg : nil, count: weights.count)
}

/// Average of the days that have entries, rounded half up; nil when there are none.
public func averageKcal(_ bars: [DayBar]) -> Int? {
    let logged = bars.compactMap(\.kcal)
    return logged.isEmpty ? nil : roundHalfUp(Double(logged.reduce(0, +)) / Double(logged.count))
}
