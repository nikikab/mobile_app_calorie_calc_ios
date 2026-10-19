import Foundation
import SwiftData
import KaloCalcCore

/// Reads and writes the diary, weights, goals and favorites as the plain values of `KaloCalcCore`.
/// Rules follow the Android DAOs (same ordering, replace-on-conflict, case-insensitive favorite names).
@MainActor
final class Repository {
    private let context: ModelContext
    private let counters: KeyValueStore

    /// `counters` remembers the last id handed out for each kind, so an id is never reused after a delete.
    init(context: ModelContext, counters: KeyValueStore) {
        self.context = context
        self.counters = counters
    }

    private func nextId(_ kind: String, highestStored: Int64) -> Int64 {
        let key = "last_id_\(kind)"
        let id = max(Int64(counters.int(key) ?? 0), highestStored) + 1
        counters.set(Int(id), for: key)
        return id
    }

    private func save() throws { if context.hasChanges { try context.save() } }

    // MARK: Diary

    func entries(forDay day: Int64) throws -> [FoodEntry] {
        try context.fetch(FetchDescriptor<FoodEntryRecord>(predicate: #Predicate { $0.epochDay == day },
                                                           sortBy: [SortDescriptor(\.id)])).map(\.value)
    }

    func allEntries() throws -> [FoodEntry] {
        try context.fetch(FetchDescriptor<FoodEntryRecord>(sortBy: [SortDescriptor(\.id)])).map(\.value)
    }

    /// Entries that have a photo, oldest first, so the newest photo of a food wins when mapped by name.
    func entriesWithPhoto() throws -> [FoodEntry] {
        try context.fetch(FetchDescriptor<FoodEntryRecord>(predicate: #Predicate { $0.photoPath != nil },
                                                           sortBy: [SortDescriptor(\.id)])).map(\.value)
    }

    /// Returns the new entry's id; `entry.id` is ignored.
    @discardableResult
    func insert(_ entry: FoodEntry) throws -> Int64 {
        var e = entry
        e.id = nextId("entry", highestStored: try highestEntryId())
        context.insert(FoodEntryRecord(e))
        try save()
        return e.id
    }

    func update(_ entry: FoodEntry) throws {
        let id = entry.id
        try context.fetch(FetchDescriptor<FoodEntryRecord>(predicate: #Predicate { $0.id == id })).first?.apply(entry)
        try save()
    }

    func deleteEntry(id: Int64) throws {
        try context.delete(model: FoodEntryRecord.self, where: #Predicate { $0.id == id })
        try save()
    }

    func deleteAllEntries() throws {
        try context.delete(model: FoodEntryRecord.self)
        try save()
    }

    /// Calories per day for the days from `from` to `to`, both included. Days without entries are left out.
    func dailyKcal(from: Int64, to: Int64) throws -> [Int64: Int] {
        let rows = try context.fetch(FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.epochDay >= from && $0.epochDay <= to }))
        return rows.reduce(into: [:]) { $0[$1.epochDay, default: 0] += $1.kcal }
    }

    // MARK: Weight

    /// One weigh-in per day; logging again on the same day replaces it.
    func upsertWeight(_ w: WeightEntry) throws {
        let day = w.epochDay
        if let existing = try context.fetch(FetchDescriptor<WeightEntryRecord>(predicate: #Predicate { $0.epochDay == day })).first {
            existing.kg = w.kg
        } else {
            context.insert(WeightEntryRecord(w))
        }
        try save()
    }

    func weights(since day: Int64) throws -> [WeightEntry] {
        try context.fetch(FetchDescriptor<WeightEntryRecord>(predicate: #Predicate { $0.epochDay >= day },
                                                             sortBy: [SortDescriptor(\.epochDay)])).map(\.value)
    }

    func allWeights() throws -> [WeightEntry] { try weights(since: Int64.min) }

    func deleteWeight(epochDay day: Int64) throws {
        try context.delete(model: WeightEntryRecord.self, where: #Predicate { $0.epochDay == day })
        try save()
    }

    // MARK: Goals

    func plans() throws -> [GoalPlan] {
        try context.fetch(FetchDescriptor<GoalPlanRecord>(sortBy: [SortDescriptor(\.id)])).map(\.value)
    }

    @discardableResult
    func insert(_ plan: GoalPlan) throws -> Int64 {
        var p = plan
        p.id = nextId("plan", highestStored: try highestPlanId())
        context.insert(GoalPlanRecord(p))
        try save()
        return p.id
    }

    func update(_ plan: GoalPlan) throws {
        let id = plan.id
        try context.fetch(FetchDescriptor<GoalPlanRecord>(predicate: #Predicate { $0.id == id })).first?.apply(plan)
        try save()
    }

    func deletePlan(id: Int64) throws {
        try context.delete(model: GoalPlanRecord.self, where: #Predicate { $0.id == id })
        try save()
    }

    // MARK: Day targets

    func dayTarget(for day: Int64) throws -> DayTarget? {
        try context.fetch(FetchDescriptor<DayTargetRecord>(predicate: #Predicate { $0.epochDay == day })).first?.value
    }

    func setDayTarget(_ t: DayTarget) throws {
        let day = t.epochDay
        if let existing = try context.fetch(FetchDescriptor<DayTargetRecord>(predicate: #Predicate { $0.epochDay == day })).first {
            existing.kcal = t.kcal
        } else {
            context.insert(DayTargetRecord(t))
        }
        try save()
    }

    func clearDayTarget(for day: Int64) throws {
        try context.delete(model: DayTargetRecord.self, where: #Predicate { $0.epochDay == day })
        try save()
    }

    // MARK: Favorites

    /// By name, ignoring case.
    func favorites() throws -> [Favorite] {
        try context.fetch(FetchDescriptor<FavoriteRecord>()).map(\.value)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Saving a dish under a name that is already a favorite replaces the old one.
    func saveFavorite(_ favorite: Favorite) throws {
        for old in try context.fetch(FetchDescriptor<FavoriteRecord>())
        where old.name.caseInsensitiveCompare(favorite.name) == .orderedSame {
            context.delete(old)
        }
        var f = favorite
        f.id = nextId("favorite", highestStored: try highestFavoriteId())
        context.insert(FavoriteRecord(f))
        try save()
    }

    func deleteFavorite(id: Int64) throws {
        try context.delete(model: FavoriteRecord.self, where: #Predicate { $0.id == id })
        try save()
    }

    // MARK: Helpers

    private func highestEntryId() throws -> Int64 {
        var d = FetchDescriptor<FoodEntryRecord>(sortBy: [SortDescriptor(\.id, order: .reverse)])
        d.fetchLimit = 1
        return try context.fetch(d).first?.id ?? 0
    }

    private func highestPlanId() throws -> Int64 {
        var d = FetchDescriptor<GoalPlanRecord>(sortBy: [SortDescriptor(\.id, order: .reverse)])
        d.fetchLimit = 1
        return try context.fetch(d).first?.id ?? 0
    }

    private func highestFavoriteId() throws -> Int64 {
        var d = FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.id, order: .reverse)])
        d.fetchLimit = 1
        return try context.fetch(d).first?.id ?? 0
    }
}
