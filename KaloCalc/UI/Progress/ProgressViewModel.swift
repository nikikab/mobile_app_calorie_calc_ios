import Foundation
import Observation
import KaloCalcCore

@MainActor
@Observable
final class ProgressViewModel {
    private static let weightDays: Int64 = 90

    private let model: AppModel
    private let today: () -> Date

    private(set) var weights: [WeightEntry] = []
    private(set) var week: [DayBar] = []
    private(set) var targetKcal = 0
    var input = ""
    var errorMessage: String?

    init(model: AppModel, today: @escaping () -> Date = Date.init) {
        self.model = model
        self.today = today
        reload()
    }

    var kg: Double? { parseWeightInput(input) }
    var trend: WeightTrend? { weightTrend(weights) }
    var average: Int? { averageKcal(week) }

    func reload() {
        let day = epochDay(of: today())
        do {
            weights = try model.repository.weights(since: day - Self.weightDays)
            week = weekBars(endingOn: day, kcalByDay: try model.repository.dailyKcal(from: day - 6, to: day))
            targetKcal = resolveTargets(profile: model.profileStore.profile, plans: try model.repository.plans(),
                                        activeId: model.profileStore.activePlanId).kcal
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    /// Also becomes the profile weight, so the calorie target and every goal's grams follow the newest weight.
    func logWeight() {
        guard let kg else { return }
        do {
            try model.repository.upsertWeight(WeightEntry(epochDay: epochDay(of: today()), kg: kg))
            model.profileStore.setWeight(kg)
            input = ""
            reload()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }
}
