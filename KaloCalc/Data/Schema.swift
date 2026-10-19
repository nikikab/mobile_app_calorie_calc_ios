import Foundation
import SwiftData
import KaloCalcCore

/// Version 1 of the on-disk schema. The Android database was at version 9 when the iOS app started; iOS begins
/// at 1. To change a model, add `KaloSchemaV2` with the new shape, list it in `KaloMigrationPlan` and add a stage.
///
/// Ids are our own `Int64`s (not SwiftData's persistent ids): the Health sync names its records after the entry id.
/// A diary entry keeps its own nutrition values, so later edits never rewrite history.
enum KaloSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [FoodEntryRecord.self, WeightEntryRecord.self, GoalPlanRecord.self, DayTargetRecord.self, FavoriteRecord.self]
    }

    @Model
    final class FoodEntryRecord {
        @Attribute(.unique) var id: Int64
        var epochDay: Int64
        var mealRaw: String
        var name: String
        var kcal: Int
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        /// File name of the JPEG inside the app's photos folder, if the entry was photographed.
        /// A name rather than a path, because the app container's path changes between installs and updates.
        var photoPath: String?
        var epochMillis: Int64
        var grams: Double

        init(_ e: FoodEntry) {
            id = e.id; epochDay = e.epochDay; mealRaw = e.meal.rawValue; name = e.name; kcal = e.kcal
            proteinG = e.proteinG; carbsG = e.carbsG; fatG = e.fatG; photoPath = e.photoPath
            epochMillis = e.epochMillis; grams = e.grams
        }

        var value: FoodEntry {
            FoodEntry(id: id, epochDay: epochDay, meal: Meal(rawValue: mealRaw) ?? .snack, name: name, kcal: kcal,
                      proteinG: proteinG, carbsG: carbsG, fatG: fatG, photoPath: photoPath,
                      epochMillis: epochMillis, grams: grams)
        }

        func apply(_ e: FoodEntry) {
            epochDay = e.epochDay; mealRaw = e.meal.rawValue; name = e.name; kcal = e.kcal
            proteinG = e.proteinG; carbsG = e.carbsG; fatG = e.fatG; photoPath = e.photoPath
            epochMillis = e.epochMillis; grams = e.grams
        }
    }

    @Model
    final class WeightEntryRecord {
        /// One weigh-in per day; logging again on the same day replaces it.
        @Attribute(.unique) var epochDay: Int64
        var kg: Double

        init(_ w: WeightEntry) { epochDay = w.epochDay; kg = w.kg }
        var value: WeightEntry { WeightEntry(epochDay: epochDay, kg: kg) }
    }

    @Model
    final class GoalPlanRecord {
        @Attribute(.unique) var id: Int64
        var name: String
        var kcal: Int
        var proteinG: Int
        var carbsG: Int
        var fatG: Int
        var baseKcal: Int

        init(_ p: GoalPlan) {
            id = p.id; name = p.name; kcal = p.kcal; proteinG = p.proteinG
            carbsG = p.carbsG; fatG = p.fatG; baseKcal = p.baseKcal
        }

        var value: GoalPlan {
            GoalPlan(id: id, name: name, kcal: kcal, proteinG: proteinG, carbsG: carbsG, fatG: fatG, baseKcal: baseKcal)
        }

        func apply(_ p: GoalPlan) {
            name = p.name; kcal = p.kcal; proteinG = p.proteinG; carbsG = p.carbsG; fatG = p.fatG; baseKcal = p.baseKcal
        }
    }

    /// A calorie target chosen by hand for one day, replacing the usual one for that day only.
    @Model
    final class DayTargetRecord {
        @Attribute(.unique) var epochDay: Int64
        var kcal: Int

        init(_ t: DayTarget) { epochDay = t.epochDay; kcal = t.kcal }
        var value: DayTarget { DayTarget(epochDay: epochDay, kcal: kcal) }
    }

    @Model
    final class FavoriteRecord {
        @Attribute(.unique) var id: Int64
        var name: String
        var grams: Double
        var kcal: Int
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var ingredients: String

        init(_ f: Favorite) {
            id = f.id; name = f.name; grams = f.grams; kcal = f.kcal
            proteinG = f.proteinG; carbsG = f.carbsG; fatG = f.fatG; ingredients = f.ingredients
        }

        var value: Favorite {
            Favorite(id: id, name: name, grams: grams, kcal: kcal, proteinG: proteinG, carbsG: carbsG,
                     fatG: fatG, ingredients: ingredients)
        }
    }
}

typealias FoodEntryRecord = KaloSchemaV1.FoodEntryRecord
typealias WeightEntryRecord = KaloSchemaV1.WeightEntryRecord
typealias GoalPlanRecord = KaloSchemaV1.GoalPlanRecord
typealias DayTargetRecord = KaloSchemaV1.DayTargetRecord
typealias FavoriteRecord = KaloSchemaV1.FavoriteRecord

enum KaloMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [KaloSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    /// The store on disk, or a throwaway one in memory (tests and previews).
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: KaloSchemaV1.self),
            migrationPlan: KaloMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }
}
