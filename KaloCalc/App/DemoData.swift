import Foundation
import KaloCalcCore

/// A filled-in, throwaway app for screenshots: started with the `-demo` launch argument.
@MainActor
extension AppModel {
    static func demo(today: Date = Date()) -> AppModel {
        let model = AppModel.inMemory()
        let day = epochDay(of: today)
        model.profileStore.save(Profile(sex: .female, age: 34, heightCm: 168, weightKg: 64.5, activity: .moderate, goal: .lose))
        let r = model.repository
        func add(_ meal: Meal, _ name: String, _ grams: Double, _ kcal: Int, _ p: Double, _ c: Double, _ f: Double) {
            _ = try? r.insert(FoodEntry(epochDay: day, meal: meal, name: name, kcal: kcal, proteinG: p, carbsG: c, fatG: f,
                                        epochMillis: entryTimeMillis(epochDay: day, now: today), grams: grams))
        }
        add(.breakfast, "Oatmeal with banana", 280, 310, 9, 56, 5)
        add(.breakfast, "Greek yogurt", 150, 98, 15, 6, 1)
        add(.lunch, "Chicken salad", 320, 420, 38, 14, 22)
        add(.lunch, "Whole-grain bread", 60, 150, 6, 28, 2)
        add(.dinner, "Baked salmon with rice", 350, 560, 36, 48, 22)
        add(.snack, "Apple", 180, 94, 0.5, 25, 0.3)
        _ = try? r.insert(GoalPlan(name: "Weekend", kcal: 1900, proteinG: 110, carbsG: 200, fatG: 65, baseKcal: calculate(model.profileStore.profile).target))
        for (name, g, k, p, c, f) in [("Greek yogurt", 150.0, 98, 15.0, 6.0, 1.0), ("Oatmeal with banana", 280.0, 310, 9.0, 56.0, 5.0)] {
            try? r.saveFavorite(Favorite(name: name, grams: g, kcal: k, proteinG: p, carbsG: c, fatG: f))
        }
        // Three weeks of weigh-ins and a week of diary days, for the Progress tab.
        let kg: [Double] = [66.1, 65.9, 65.8, 65.4, 65.5, 65.0, 64.9, 64.5]
        for (i, w) in kg.enumerated() { try? r.upsertWeight(WeightEntry(epochDay: day - Int64((kg.count - 1 - i) * 3), kg: w)) }
        let past = [1: 1720, 2: 2050, 3: 1890, 5: 2240, 6: 1610]
        for (back, kcal) in past {
            let d = day - Int64(back)
            _ = try? r.insert(FoodEntry(epochDay: d, meal: .lunch, name: "Meals", kcal: kcal, epochMillis: entryTimeMillis(epochDay: d, now: today)))
        }
        return model
    }
}
