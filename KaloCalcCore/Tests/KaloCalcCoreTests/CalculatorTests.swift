import XCTest
@testable import KaloCalcCore

final class CalculatorTests: XCTestCase {
    func testMaleBmr() {
        let r = calculate(Profile(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .sedentary, goal: .maintain))
        XCTAssertEqual(r.bmr, 1780) // 800 + 1125 - 150 + 5
        XCTAssertEqual(r.tdee, 2136)
    }

    func testFemaleLoseGoal() {
        let r = calculate(Profile(sex: .female, age: 25, heightCm: 165, weightKg: 60, activity: .moderate, goal: .lose))
        XCTAssertEqual(r.bmr, 1345)
        XCTAssertEqual(r.tdee, 2085)
        XCTAssertEqual(r.target, 1585)
    }

    func testMacroGoalsSplit() {
        XCTAssertEqual(macroGoals(targetKcal: 2000), MacroGoals(150, 200, 67))
    }

    func testInsulinResistanceMovesCarbsToFat() {
        XCTAssertEqual(macroGoals(targetKcal: 2000, insulinResistance: true), MacroGoals(150, 175, 78))
    }

    func testInsulinResistanceDoesNotChangeCalories() {
        let base = Profile(sex: .female, age: 41, heightCm: 168, weightKg: 63.5, activity: .light, goal: .lose)
        var ir = base; ir.insulinResistance = true
        XCTAssertEqual(calculate(base), calculate(ir))
    }

    func testFibreFollowsCaloriesWithAFloor() {
        XCTAssertEqual(intakeLimits(targetKcal: 1500).fiberMinG, 25)
        XCTAssertEqual(intakeLimits(targetKcal: 2400).fiberMinG, 34)
    }

    func testFreeSugarIsFivePercentOfCalories() {
        XCTAssertEqual(intakeLimits(targetKcal: 2000).freeSugarMaxG, 25)
        XCTAssertEqual(intakeLimits(targetKcal: 1500).freeSugarMaxG, 19)
    }

    func testRoundingMatchesKotlinForNegativeHalves() {
        XCTAssertEqual(roundHalfUp(-2.5), -2)
        XCTAssertEqual(roundHalfUp(2.5), 3)
        XCTAssertEqual(roundHalfUp(-180.4), -180)
    }
}
