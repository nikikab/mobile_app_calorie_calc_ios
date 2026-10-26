import Foundation
import KaloCalcCore

extension Meal {
    var label: String {
        switch self {
        case .breakfast: tr("meal_breakfast")
        case .lunch: tr("meal_lunch")
        case .dinner: tr("meal_dinner")
        case .snack: tr("meal_snack")
        }
    }
}

extension Sex {
    var label: String {
        switch self {
        case .male: tr("sex_male")
        case .female: tr("sex_female")
        }
    }
}

extension ActivityLevel {
    var label: String {
        switch self {
        case .sedentary: tr("activity_sedentary")
        case .light: tr("activity_light")
        case .moderate: tr("activity_moderate")
        case .high: tr("activity_high")
        case .extreme: tr("activity_extreme")
        }
    }
}

extension Goal {
    var label: String {
        switch self {
        case .lose: tr("goal_lose")
        case .maintain: tr("goal_maintain")
        case .gain: tr("goal_gain")
        }
    }
}

extension MeasureUnit {
    var label: String {
        switch self {
        case .g: tr("unit_g")
        case .ml: tr("unit_ml")
        case .tbsp: tr("unit_tbsp")
        case .tsp: tr("unit_tsp")
        case .cup: tr("unit_cup")
        case .piece: tr("unit_piece")
        }
    }
}
