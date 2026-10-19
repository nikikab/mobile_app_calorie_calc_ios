import XCTest
@testable import KaloCalcCore

final class FavoriteTests: XCTestCase {
    func testIngredientsRoundTrip() {
        let list = [Ingredient(name: "Ориз", grams: 150, kcal: 195, proteinG: 4, carbsG: 42, fatG: 0.5)]
        XCTAssertEqual(ingredientsFromJson(ingredientsToJson(list)), list)
        XCTAssertEqual(ingredientsToJson([]), "")
    }

    func testDamagedIngredientListMeansNoIngredients() {
        XCTAssertEqual(ingredientsFromJson("not json"), [])
        XCTAssertEqual(ingredientsFromJson(""), [])
        XCTAssertEqual(ingredientsFromJson(#"{"a":1}"#), [])
    }

    func testIngredientsWithoutNameOrWeightAreDropped() {
        let json = #"[{"name":"","grams":5},{"name":"Сол","grams":0},{"name":"Хляб","grams":40,"kcal":100},7]"#
        XCTAssertEqual(ingredientsFromJson(json).map(\.name), ["Хляб"])
    }

    func testEstimateRoundTripThroughAFavorite() {
        let e = FoodEstimate(name: "  Салата ", grams: 200, kcal: 150.5, proteinG: 3, carbsG: 10, fatG: 8,
                             ingredients: [Ingredient(name: "Домат", grams: 100, kcal: 20, proteinG: 1, carbsG: 4, fatG: 0)])
        let f = e.toFavorite()
        XCTAssertEqual(f.name, "Салата")
        XCTAssertEqual(f.kcal, 151)
        XCTAssertEqual(f.toEstimate().ingredients, e.ingredients)
    }

    func testUsable() {
        let ok = Favorite(name: "Яйце", grams: 60, kcal: 90, proteinG: 7, carbsG: 0, fatG: 6)
        XCTAssertTrue(ok.isUsable)
        var bad = ok; bad.name = "  "; XCTAssertFalse(bad.isUsable)
        bad = ok; bad.grams = 0; XCTAssertFalse(bad.isUsable)
        bad = ok; bad.kcal = maxPlanKcal + 1; XCTAssertFalse(bad.isUsable)
        bad = ok; bad.fatG = -1; XCTAssertFalse(bad.isUsable)
        bad = ok; bad.name = String(repeating: "я", count: maxFavoriteName + 1); XCTAssertFalse(bad.isUsable)
    }
}

final class ProfileStoreTests: XCTestCase {
    func testEmptyStoreGivesTheDefaults() {
        let s = ProfileStore(MemoryKeyValueStore())
        XCTAssertEqual(s.profile, Profile())
        XCTAssertEqual(s.activePlanId, 0)
    }

    func testSaveAndReadBack() {
        let s = ProfileStore(MemoryKeyValueStore())
        let p = Profile(sex: .female, age: 41, heightCm: 168, weightKg: 62.5, activity: .high, goal: .lose, insulinResistance: true)
        s.save(p)
        XCTAssertEqual(s.profile, p)
    }

    func testUnknownStoredValuesFallBackToDefaults() {
        let kv = MemoryKeyValueStore()
        kv.set("ALIEN", for: "sex"); kv.set("???", for: "goal")
        let p = ProfileStore(kv).profile
        XCTAssertEqual(p.sex, Profile().sex)
        XCTAssertEqual(p.goal, Profile().goal)
    }

    func testBuiltInGoalDeselectsTheSavedGoal() {
        let s = ProfileStore(MemoryKeyValueStore())
        s.setActivePlan(7)
        XCTAssertEqual(s.activePlanId, 7)
        s.setBuiltInGoal(.gain)
        XCTAssertEqual(s.activePlanId, 0)
        XCTAssertEqual(s.profile.goal, .gain)
    }

    func testLoggedWeightUpdatesOnlyTheWeight() {
        let s = ProfileStore(MemoryKeyValueStore())
        s.save(Profile(age: 50))
        s.setWeight(81.2)
        XCTAssertEqual(s.profile.weightKg, 81.2)
        XCTAssertEqual(s.profile.age, 50)
    }
}

final class SettingsStoreTests: XCTestCase {
    func make() -> (SettingsStore, MemoryKeyValueStore, MemoryKeyValueStore) {
        let kv = MemoryKeyValueStore(), secrets = MemoryKeyValueStore()
        return (SettingsStore(kv, secrets: secrets), kv, secrets)
    }

    func testDefaults() {
        let (s, _, _) = make()
        XCTAssertEqual(s.gemini, GeminiSettings())
        XCTAssertFalse(s.gemini.enabled)
    }

    func testKeyGoesToTheSecretStoreOnly() {
        let (s, kv, secrets) = make()
        s.saveKey("  abc  ")
        XCTAssertEqual(s.gemini.apiKey, "abc")
        XCTAssertEqual(secrets.secret("gemini_key"), "abc")
        XCTAssertNil(kv.string("gemini_key"))
        s.saveKey("   ")
        XCTAssertFalse(s.gemini.enabled)
    }

    func testInvalidModelIsIgnored() {
        let (s, _, _) = make()
        s.saveModel("bad/model")
        XCTAssertEqual(s.gemini.model, defaultGeminiModel)
        s.saveModel("models/gemini-x.1")
        XCTAssertEqual(s.gemini.model, "gemini-x.1")
    }

    func testCustomModelIsAddedSelectedAndRemoved() {
        let (s, _, _) = make()
        XCTAssertFalse(s.addCustomModel("a b"))
        XCTAssertTrue(s.addCustomModel("my-model"))
        XCTAssertTrue(s.addCustomModel("my-model"))
        XCTAssertEqual(s.gemini.customModels, ["my-model"])
        XCTAssertEqual(s.gemini.model, "my-model")
        s.removeCustomModel("my-model")
        XCTAssertEqual(s.gemini.customModels, [])
        XCTAssertEqual(s.gemini.model, defaultGeminiModel)
    }

    func testPresetIsSelectedButNotStoredAsCustom() {
        let (s, _, _) = make()
        XCTAssertTrue(s.addCustomModel(presetGeminiModels[1]))
        XCTAssertEqual(s.gemini.customModels, [])
        XCTAssertEqual(s.gemini.model, presetGeminiModels[1])
    }
}
