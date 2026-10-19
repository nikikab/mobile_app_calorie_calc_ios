import Foundation

public enum Meal: String, Codable, CaseIterable {
    case breakfast = "BREAKFAST", lunch = "LUNCH", dinner = "DINNER", snack = "SNACK"

    /// The meal a dish most likely belongs to at `hour` (0-23); the user can still pick another one.
    public static func forHour(_ hour: Int) -> Meal {
        switch hour {
        case 5...10: return .breakfast
        case 11...14: return .lunch
        case 18...21: return .dinner
        default: return .snack
        }
    }

    public static func now(calendar: Calendar = .current, date: Date = Date()) -> Meal {
        forHour(calendar.component(.hour, from: date))
    }
}

/// Denormalized on purpose: a diary row keeps its own nutrition values, so later edits to a food DB don't rewrite history.
public struct FoodEntry: Equatable, Codable {
    public var id: Int64
    public var epochDay: Int64
    public var meal: Meal
    public var name: String
    public var kcal: Int
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var photoPath: String?
    /// When the dish was logged, in epoch milliseconds; 0 for entries made before the time was stored.
    public var epochMillis: Int64
    /// Weight of the portion in grams; 0 when it isn't known.
    public var grams: Double

    public init(id: Int64 = 0, epochDay: Int64, meal: Meal, name: String, kcal: Int, proteinG: Double = 0,
                carbsG: Double = 0, fatG: Double = 0, photoPath: String? = nil, epochMillis: Int64 = 0, grams: Double = 0) {
        self.id = id; self.epochDay = epochDay; self.meal = meal; self.name = name; self.kcal = kcal
        self.proteinG = proteinG; self.carbsG = carbsG; self.fatG = fatG; self.photoPath = photoPath
        self.epochMillis = epochMillis; self.grams = grams
    }

    /// This entry as if the portion weighed `newGrams`: calories and macros scale in proportion to the weight.
    /// Nil when there is nothing to scale from, i.e. the stored weight or the new one isn't positive.
    public func scaled(to newGrams: Double) -> FoodEntry? {
        if grams <= 0 || newGrams <= 0 { return nil }
        let f = newGrams / grams
        var copy = self
        copy.grams = newGrams
        copy.kcal = roundHalfUp(Double(kcal) * f)
        copy.proteinG = proteinG * f
        copy.carbsG = carbsG * f
        copy.fatG = fatG * f
        return copy
    }

    /// When this entry happened; entries without a stored time count as midday of their day.
    public func startDate(calendar: Calendar = .current) -> Date {
        epochMillis > 0 ? Date(timeIntervalSince1970: Double(epochMillis) / 1000) : middayDate(epochDay: epochDay, calendar: calendar)
    }
}

private let utc = TimeZone(identifier: "UTC")!

/// Days since 1970-01-01 of the calendar day `date` falls on in `calendar`'s time zone.
public func epochDay(of date: Date, calendar: Calendar = .current) -> Int64 {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    var u = Calendar(identifier: .gregorian)
    u.timeZone = utc
    let start = u.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
    return Int64((start.timeIntervalSince1970 / 86400).rounded(.down))
}

/// 12:00 local time on the day `epochDay`.
public func middayDate(epochDay: Int64, calendar: Calendar = .current) -> Date {
    var u = Calendar(identifier: .gregorian)
    u.timeZone = utc
    let c = u.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(epochDay) * 86400))
    return calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12))!
}

/// The moment to store for a dish added to `epochDay`: now for today, otherwise midday of that day (epoch ms).
public func entryTimeMillis(epochDay day: Int64, now: Date = Date(), calendar: Calendar = .current) -> Int64 {
    let moment = day == epochDay(of: now, calendar: calendar) ? now : middayDate(epochDay: day, calendar: calendar)
    return Int64((moment.timeIntervalSince1970 * 1000).rounded())
}

public struct WeightEntry: Equatable, Codable {
    public var epochDay: Int64
    public var kg: Double
    public init(epochDay: Int64, kg: Double) { self.epochDay = epochDay; self.kg = kg }
}

/// A calorie target chosen by hand for one day, replacing the usual one for that day only.
public struct DayTarget: Equatable, Codable {
    public var epochDay: Int64
    public var kcal: Int
    public init(epochDay: Int64, kcal: Int) { self.epochDay = epochDay; self.kcal = kcal }
    public var isUsable: Bool { (1...maxPlanKcal).contains(kcal) }
}

/// The id that ties a diary entry to its Health record, so writing twice replaces instead of duplicating.
public func clientRecordId(entryId: Int64) -> String { "kalocalc-\(entryId)" }
