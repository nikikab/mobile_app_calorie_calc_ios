import XCTest
@testable import KaloCalcCore

final class DaySummaryTests: XCTestCase {
    let profile = Profile()
    func entry(_ kcal: Int, p: Double = 0, c: Double = 0, f: Double = 0) -> FoodEntry {
        FoodEntry(epochDay: 1, meal: .lunch, name: "x", kcal: kcal, proteinG: p, carbsG: c, fatG: f)
    }

    func testTotalsAndTheUsualTarget() {
        let s = summarizeDay(entries: [entry(500, p: 20, c: 50, f: 10), entry(300, p: 10)], profile: profile, plans: [], activePlanId: 0, dayTarget: nil)
        let target = calculate(profile).target
        XCTAssertEqual(s.kcal, 800)
        XCTAssertEqual(s.proteinG, 30)
        XCTAssertEqual(s.targetKcal, target)
        XCTAssertEqual(s.defaultKcal, target)
        XCTAssertFalse(s.isCustomTarget)
        XCTAssertEqual(s.remainingKcal, target - 800)
        XCTAssertEqual(s.goals, macroGoals(targetKcal: target))
    }

    func testTypedInTargetReplacesCaloriesAndScalesMacros() {
        let usual = summarizeDay(entries: [], profile: profile, plans: [], activePlanId: 0, dayTarget: nil)
        let s = summarizeDay(entries: [], profile: profile, plans: [], activePlanId: 0,
                             dayTarget: DayTarget(epochDay: 1, kcal: usual.targetKcal / 2))
        XCTAssertTrue(s.isCustomTarget)
        XCTAssertEqual(s.targetKcal, usual.targetKcal / 2)
        XCTAssertEqual(s.defaultKcal, usual.targetKcal)
        XCTAssertLessThan(s.goals.carbsG, usual.goals.carbsG)
    }

    func testSelectedPlanIsUsed() {
        let plan = GoalPlan(id: 3, name: "P", kcal: 1800, proteinG: 100, carbsG: 200, fatG: 50, baseKcal: calculate(profile).target)
        let s = summarizeDay(entries: [], profile: profile, plans: [plan], activePlanId: 3, dayTarget: nil)
        XCTAssertEqual(s.targetKcal, 1800)
        XCTAssertEqual(s.goals, MacroGoals(100, 200, 50))
    }

    func testProgressIsClampedAndSafeWithoutAGoal() {
        let over = summarizeDay(entries: [entry(99_999)], profile: profile, plans: [], activePlanId: 0, dayTarget: nil)
        XCTAssertEqual(over.kcalProgress, 1)
        XCTAssertLessThan(over.remainingKcal, 0)
        let none = DaySummary(targetKcal: 0, goals: MacroGoals(0, 0, 0), defaultKcal: 0, isCustomTarget: false, kcal: 5, proteinG: 1, carbsG: 1, fatG: 1)
        XCTAssertEqual(none.kcalProgress, 0)
        XCTAssertEqual(none.proteinProgress, 0)
    }
}

final class InputTests: XCTestCase {
    func testDecimalAcceptsAComma() {
        XCTAssertEqual(parseDecimal("72,5"), 72.5)
        XCTAssertEqual(parseDecimal(" 3 "), 3)
        XCTAssertNil(parseDecimal("abc"))
    }

    func testGramsTextDropsTrailingZero() {
        XCTAssertEqual(gramsText(150), "150")
        XCTAssertEqual(gramsText(12.5), "12.5")
    }

    func testProfileInputRanges() {
        func p(_ age: String = "30", h: String = "175", w: String = "75") -> Profile? {
            parseProfileInput(sex: .male, age: age, height: h, weight: w, activity: .light, goal: .maintain, insulinResistance: false)
        }
        XCTAssertEqual(p()?.weightKg, 75)
        XCTAssertEqual(p(w: "75,5")?.weightKg, 75.5)
        XCTAssertNil(p("9")); XCTAssertNil(p("121")); XCTAssertNil(p(h: "99")); XCTAssertNil(p(h: "251"))
        XCTAssertNil(p(w: "29.9")); XCTAssertNil(p(w: "300.1")); XCTAssertNil(p("")); XCTAssertNil(p(w: "x"))
        XCTAssertNotNil(p("10", h: "100", w: "30")); XCTAssertNotNil(p("120", h: "250", w: "300"))
    }

    func testEntryInput() {
        let v = parseEntryInput(meal: .dinner, name: "  Супа ", grams: "250", kcal: "120", protein: "5,5", carbs: "", fat: "2")
        XCTAssertEqual(v, EntryValues(meal: .dinner, name: "Супа", grams: 250, kcal: 120, proteinG: 5.5, carbsG: 0, fatG: 2))
    }

    func testEntryInputRejectsBadFields() {
        func v(name: String = "x", kcal: String = "10", protein: String = "") -> EntryValues? {
            parseEntryInput(meal: .snack, name: name, grams: "", kcal: kcal, protein: protein, carbs: "", fat: "")
        }
        XCTAssertNotNil(v())
        XCTAssertNil(v(name: "  ")); XCTAssertNil(v(kcal: "")); XCTAssertNil(v(kcal: "-1")); XCTAssertNil(v(kcal: "1.5"))
        XCTAssertNil(v(protein: "abc"))
        XCTAssertEqual(parseEntryInput(meal: .snack, name: "x", grams: "0", kcal: "0", protein: "", carbs: "", fat: "")?.grams, 0)
        XCTAssertEqual(parseEntryInput(meal: .snack, name: "x", grams: "-5", kcal: "0", protein: "", carbs: "", fat: "")?.grams, 0)
    }

    func testRebasedPlanScalesFromTodaysTarget() {
        let plan = GoalPlan(id: 4, name: "P", kcal: 2000, proteinG: 100, carbsG: 200, fatG: 60, baseKcal: 2000)
        let r = plan.rebased(onTarget: 1000)
        XCTAssertEqual([r.kcal, r.proteinG, r.carbsG, r.fatG, r.baseKcal], [1000, 50, 100, 30, 1000])
        XCTAssertEqual(r.id, 4)
        XCTAssertEqual(r.name, "P")
    }
}
