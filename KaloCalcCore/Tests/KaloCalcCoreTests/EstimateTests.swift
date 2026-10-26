import XCTest
@testable import KaloCalcCore

final class FoodLabelsTests: XCTestCase {
    func label(_ t: String, _ c: Float) -> FoodLabel { FoodLabel(text: t, confidence: c) }

    func testGenericLabelsAreDroppedAndTheRestSortedByConfidence() {
        let r = specificFoodLabels([label("Food", 0.99), label("Pizza", 0.6), label("Tableware", 0.9), label("Salad", 0.8)])
        XCTAssertEqual(r.map(\.text), ["Salad", "Pizza"])
    }

    func testAtMostFiveAreKept() {
        let many = (1...8).map { label("dish\($0)x", Float($0) / 10) }
        XCTAssertEqual(specificFoodLabels(many).count, 5)
        XCTAssertEqual(specificFoodLabels(many).first?.text, "dish8x")
        XCTAssertEqual(specificFoodLabels(many, max: 2).count, 2)
    }

    func testUnderscoresBecomeSpaces() {
        XCTAssertEqual(specificFoodLabels([label("french_fries", 0.7)]).map(\.text), ["french fries"])
        XCTAssertTrue(specificFoodLabels([label("staple_food", 0.9)]).isEmpty)
    }
}

final class PortionTests: XCTestCase {
    func testScalesPer100gValues() {
        let p = Product(name: "Мляко", brand: "", kcal100: 47, protein100: 3.3, carbs100: 4.8, fat100: 1.5)
        let r = p.portion(grams: 250)
        XCTAssertEqual(r.kcal, 118)
        XCTAssertEqual(r.proteinG, 8.25, accuracy: 1e-9)
        XCTAssertEqual(p.portion(grams: 100).kcal, 47)
    }
}

final class EstimateEditorTests: XCTestCase {
    func ing(_ n: String, _ g: Double, _ k: Double, p: Double = 0, c: Double = 0, f: Double = 0) -> Ingredient {
        Ingredient(name: n, grams: g, kcal: k, proteinG: p, carbsG: c, fatG: f)
    }
    var plate: FoodEstimate {
        FoodEstimate(name: "Пиле с ориз", grams: 300, kcal: 450, proteinG: 30, carbsG: 50, fatG: 12,
                     ingredients: [ing("Пиле", 150, 250, p: 30, f: 8), ing("Ориз", 150, 200, c: 50, f: 4)])
    }

    func testStartsFromTheEstimate() {
        let e = EstimateEditor(plate)
        XCTAssertEqual([e.grams, e.kcal, e.protein, e.carbs, e.fat], ["300", "450", "30", "50", "12"])
        XCTAssertEqual(e.ingredientGrams, ["150", "150"])
    }

    func testChangingGramsRescalesFromTheOriginalEstimate() {
        var e = EstimateEditor(plate)
        e.changeGrams("150")
        XCTAssertEqual([e.kcal, e.protein, e.carbs, e.fat], ["225", "15", "25", "6"])
        e.changeGrams("600")
        XCTAssertEqual(e.kcal, "900")
        e.changeGrams("")
        XCTAssertEqual(e.kcal, "900")
    }

    func testChangingAnIngredientResumsTheDish() {
        var e = EstimateEditor(plate)
        e.changeIngredientGrams(1, "75")
        XCTAssertEqual(e.grams, "225")
        XCTAssertEqual(e.kcal, "350")
        XCTAssertEqual(e.carbs, "25")
        XCTAssertEqual(e.fat, "10")
    }

    func testRemovingAnIngredientResums() {
        var e = EstimateEditor(plate)
        e.removeIngredient(0)
        XCTAssertEqual(e.items.map(\.name), ["Ориз"])
        XCTAssertEqual(e.grams, "150")
        XCTAssertEqual(e.kcal, "200")
    }

    func testRemovingTheLastIngredientKeepsTheTotals() {
        var e = EstimateEditor(FoodEstimate(name: "X", grams: 100, kcal: 80, proteinG: 1, carbsG: 2, fatG: 3, ingredients: [ing("X", 100, 80)]))
        e.removeIngredient(0)
        XCTAssertEqual(e.kcal, "80")
        XCTAssertEqual(e.grams, "100")
    }

    func testAddingAnIngredientResums() {
        var e = EstimateEditor(plate)
        e.addIngredient(ing("Сол", 5, 0))
        e.addIngredient(ing("Масло", 10, 90, f: 10))
        XCTAssertEqual(e.grams, "315")
        XCTAssertEqual(e.kcal, "540")
        XCTAssertEqual(e.fat, "22")
        XCTAssertEqual(e.ingredientGrams.last, "10")
    }

    func testIndexesOutOfRangeAreIgnored() {
        var e = EstimateEditor(plate)
        e.removeIngredient(5)
        e.changeIngredientGrams(-1, "9")
        XCTAssertEqual(e, EstimateEditor(plate))
    }

    func testResultUsesTheFieldsAndRescalesIngredientsToATypedTotal() throws {
        var e = EstimateEditor(plate)
        e.grams = "600"
        e.kcal = "900"
        let r = try XCTUnwrap(e.result)
        XCTAssertEqual(r.grams, 600)
        XCTAssertEqual(r.kcal, 900)
        XCTAssertEqual(r.ingredients.map(\.grams), [300, 300])
        XCTAssertEqual(r.ingredients.map(\.kcal), [500, 400])
    }

    func testResultKeepsIngredientsAsTheyAreWhenTheTotalMatches() throws {
        let r = try XCTUnwrap(EstimateEditor(plate).result)
        XCTAssertEqual(r.ingredients, plate.ingredients)
    }

    func testResultIsNilForBadFields() {
        var e = EstimateEditor(plate)
        e.name = "  "; XCTAssertNil(e.result)
        e = EstimateEditor(plate); e.kcal = "-1"; XCTAssertNil(e.result)
        e = EstimateEditor(plate); e.kcal = "1.5"; XCTAssertNil(e.result)
        e = EstimateEditor(plate); e.protein = "abc"; XCTAssertNil(e.result)
        e = EstimateEditor(plate); e.protein = ""; XCTAssertEqual(e.result?.proteinG, 0)
    }

    func testBadGramsFallBackToTheEstimateWeight() {
        var e = EstimateEditor(plate)
        e.grams = "abc"
        XCTAssertEqual(e.result?.grams, 300)
    }

    func testIngredientsWithoutWeightAreLeftOut() throws {
        var e = EstimateEditor(plate)
        e.changeIngredientGrams(0, "0")
        let r = try XCTUnwrap(e.result)
        XCTAssertEqual(r.ingredients.map(\.name), ["Ориз"])
    }
}

final class RecipeEditorTests: XCTestCase {
    func testADishBuiltFromNothingFillsInFromItsIngredients() {
        var e = EstimateEditor(FoodEstimate(name: "", grams: 0, kcal: 0, proteinG: 0, carbsG: 0, fatG: 0))
        XCTAssertEqual(e.grams, "")
        e.changeGrams("200")
        XCTAssertEqual(e.kcal, "", "nothing to scale from, so the calories are left alone")
        e.addIngredient(Ingredient(name: "Oil", grams: 15, kcal: 130, proteinG: 0, carbsG: 0, fatG: 15))
        e.addIngredient(Ingredient(name: "Rice", grams: 100, kcal: 130, proteinG: 2.5, carbsG: 28, fatG: 0.3))
        XCTAssertEqual(e.grams, "115")
        XCTAssertEqual(e.kcal, "260")
        e.name = "Rice with oil"
        XCTAssertEqual(e.result?.ingredients.count, 2)
    }
}
