import Foundation
import Observation
import KaloCalcCore

@MainActor
@Observable
final class DiaryViewModel {
    private let model: AppModel
    private(set) var day: Int64
    private(set) var entries: [FoodEntry] = []
    private(set) var favorites: [Favorite] = []
    private(set) var summary: DaySummary
    var errorMessage: String?

    init(model: AppModel, today: Date = Date()) {
        self.model = model
        day = epochDay(of: today)
        summary = summarizeDay(entries: [], profile: model.profileStore.profile, plans: [], activePlanId: 0, dayTarget: nil)
        reload()
    }

    var date: Date { middayDate(epochDay: day) }
    var isToday: Bool { day == epochDay(of: Date()) }

    func entries(for meal: Meal) -> [FoodEntry] { entries.filter { $0.meal == meal } }
    func kcal(for meal: Meal) -> Int { entries(for: meal).reduce(0) { $0 + $1.kcal } }

    /// Reads everything for the shown day again; the profile and goals may have changed on another tab.
    func reload() {
        perform {
            let repo = model.repository
            entries = try repo.entries(forDay: day)
            favorites = try repo.favorites()
            summary = summarizeDay(entries: entries, profile: model.profileStore.profile, plans: try repo.plans(),
                                   activePlanId: model.profileStore.activePlanId, dayTarget: try repo.dayTarget(for: day))
        }
    }

    func shiftDay(_ delta: Int64) {
        day += delta
        reload()
    }

    func add(_ v: EntryValues) {
        perform {
            try model.repository.insert(FoodEntry(
                epochDay: day, meal: v.meal, name: v.name, kcal: v.kcal, proteinG: v.proteinG, carbsG: v.carbsG, fatG: v.fatG,
                epochMillis: entryTimeMillis(epochDay: day), grams: v.grams))
            reload()
        }
    }

    /// Keeps the entry's day, time and photo; only what the user can change in the dialog is replaced.
    func update(_ entry: FoodEntry, with v: EntryValues) {
        var changed = entry
        changed.meal = v.meal; changed.name = v.name; changed.grams = v.grams; changed.kcal = v.kcal
        changed.proteinG = v.proteinG; changed.carbsG = v.carbsG; changed.fatG = v.fatG
        perform {
            try model.repository.update(changed)
            reload()
        }
    }

    func delete(_ entry: FoodEntry) {
        perform {
            try model.repository.deleteEntry(id: entry.id)
            reload()
        }
    }

    /// Sets the calorie target for the shown day only.
    func setDayTarget(_ kcal: Int) {
        let target = DayTarget(epochDay: day, kcal: kcal)
        guard target.isUsable else { return }
        perform {
            try model.repository.setDayTarget(target)
            reload()
        }
    }

    func clearDayTarget() {
        perform {
            try model.repository.clearDayTarget(for: day)
            reload()
        }
    }

    func removeFavorite(_ favorite: Favorite) {
        perform {
            try model.repository.deleteFavorite(id: favorite.id)
            reload()
        }
    }

    private func perform(_ work: () throws -> Void) {
        do { try work() } catch { errorMessage = userMessage(for: error) }
    }
}
