import XCTest
@testable import KaloCalcCore

final class GoalPlanTests: XCTestCase {
    let profile = Profile(sex: .female, age: 41, heightCm: 168, weightKg: 80, activity: .light, goal: .maintain)
    let plan = GoalPlan(id: 5, name: "Low carb", kcal: 1800, proteinG: 150, carbsG: 100, fatG: 60, baseKcal: 2000)

    func testPlanKeepsItsValuesAtTheSameTarget() {
        XCTAssertEqual(plan.scaled(to: 2000), DayTargets(1800, MacroGoals(150, 100, 60)))
    }

    func testEverythingScalesInTheSameProportion() {
        XCTAssertEqual(plan.scaled(to: 1000), DayTargets(900, MacroGoals(75, 50, 30)))
    }

    func testPlanWithoutAReferenceTargetIsNotScaled() {
        var p = plan; p.baseKcal = 0
        XCTAssertEqual(p.scaled(to: 1000).kcal, 1800)
    }

    func testMacrosDoNotHaveToMatchTheCalories() { XCTAssertTrue(plan.isUsable) }

    func testUnusablePlansAreRejected() {
        func with(_ f: (inout GoalPlan) -> Void) -> GoalPlan { var p = plan; f(&p); return p }
        XCTAssertFalse(with { $0.name = "  " }.isUsable)
        XCTAssertFalse(with { $0.name = String(repeating: "x", count: 41) }.isUsable)
        XCTAssertFalse(with { $0.kcal = 0 }.isUsable)
        XCTAssertFalse(with { $0.kcal = 10_001 }.isUsable)
        XCTAssertFalse(with { $0.carbsG = -1 }.isUsable)
        XCTAssertFalse(with { $0.fatG = 1_001 }.isUsable)
        XCTAssertFalse(with { $0.baseKcal = 0 }.isUsable)
    }

    func testSelectedPlanReplacesCaloriesAndMacros() {
        var saved = plan; saved.baseKcal = calculate(profile).target
        XCTAssertEqual(resolveTargets(profile: profile, plans: [saved], activeId: 5), DayTargets(1800, MacroGoals(150, 100, 60)))
    }

    func testNoOrUnknownSelectionUsesTheProfileAndItsDefaultSplit() {
        let target = calculate(profile).target
        for id: Int64 in [0, 99] {
            let t = resolveTargets(profile: profile, plans: [plan], activeId: id)
            XCTAssertEqual(t.kcal, target)
            XCTAssertEqual(t.macros, macroGoals(targetKcal: target, split: standardSplit))
        }
        var ir = profile; ir.insulinResistance = true
        XCTAssertEqual(resolveTargets(profile: ir, plans: [plan], activeId: 0).macros,
                       macroGoals(targetKcal: target, split: insulinResistanceSplit))
    }

    func testLighterWeightScalesEveryValueOfAGoalSavedAtTheOldWeight() {
        let savedAt = calculate(profile).target
        var saved = plan; saved.baseKcal = savedAt
        var lighter = profile; lighter.weightKg = 70
        let now = calculate(lighter).target
        let t = resolveTargets(profile: lighter, plans: [saved], activeId: 5)
        let ratio = Double(now) / Double(savedAt)
        XCTAssertLessThan(now, savedAt)
        XCTAssertEqual(1800 * ratio, Double(t.kcal), accuracy: 1)
        XCTAssertEqual(150 * ratio, Double(t.macros.proteinG), accuracy: 1)
        XCTAssertEqual(100 * ratio, Double(t.macros.carbsG), accuracy: 1)
        XCTAssertEqual(60 * ratio, Double(t.macros.fatG), accuracy: 1)
    }

    func testDayTargetRescalesTheMacrosInTheSameProportion() {
        XCTAssertEqual(DayTargets(2000, MacroGoals(150, 200, 67)).withKcal(1500), DayTargets(1500, MacroGoals(113, 150, 50)))
    }

    func testSameDayTargetChangesNothing() {
        let usual = DayTargets(2000, MacroGoals(150, 200, 67))
        XCTAssertEqual(usual.withKcal(2000), usual)
    }

    func testDayTargetWithoutAUsualTargetOnlySetsTheCalories() {
        XCTAssertEqual(DayTargets(0, MacroGoals(0, 0, 0)).withKcal(1500), DayTargets(1500, MacroGoals(0, 0, 0)))
    }
}
