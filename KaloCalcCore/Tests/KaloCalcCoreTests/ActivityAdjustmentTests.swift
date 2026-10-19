import XCTest
@testable import KaloCalcCore

final class ActivityAdjustmentTests: XCTestCase {
    // Expected 640 gives a tolerance of 160 kcal.
    func adj(_ actual: Double?, finished: Bool = true) -> Int { activityAdjustment(expected: 640, actual: actual, dayFinished: finished) }

    func testInsideTheBandNothingChanges() {
        XCTAssertEqual(adj(700), 0); XCTAssertEqual(adj(800), 0); XCTAssertEqual(adj(480), 0)
    }

    func testOnlyThePartBeyondTheBandCounts() {
        XCTAssertEqual(adj(900), 100); XCTAssertEqual(adj(1000), 200)
        XCTAssertEqual(adj(1400), 600); XCTAssertEqual(adj(300), -180)
    }

    func testMovesSmoothlyAcrossTheEdge() { XCTAssertEqual(adj(800), 0); XCTAssertEqual(adj(801), 1) }

    func testSmallExpectationStillGetsTheMinimumBand() {
        XCTAssertEqual(activityAdjustment(expected: 200, actual: 290, dayFinished: true), 0)
        XCTAssertEqual(activityAdjustment(expected: 200, actual: 350, dayFinished: true), 50)
    }

    func testAnUnfinishedDayOnlyGoesUp() {
        XCTAssertEqual(adj(100, finished: false), 0)
        XCTAssertEqual(adj(1000, finished: false), 200)
    }

    func testNoReadingChangesNothing() { XCTAssertEqual(adj(nil), 0) }

    func testExpectedActivityIsWhatTheFactorAddsToTheBmr() {
        let p = Profile(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .light, goal: .maintain)
        XCTAssertEqual(expectedActiveKcal(p), Double(calculate(p).bmr) * 0.375, accuracy: 0.001)
    }

    let targets = DayTargets(2000, MacroGoals(150, 200, 67))

    func testRaisingScalesTheMacrosAlong() {
        let t = applyActivityAdjustment(targets, bmr: 1700, adjustment: 200)
        XCTAssertEqual(t.kcal, 2200); XCTAssertEqual(t.macros.proteinG, 165)
    }

    func testLoweringStopsAtTheBmr() {
        XCTAssertEqual(applyActivityAdjustment(targets, bmr: 1700, adjustment: -600).kcal, 1700)
        XCTAssertEqual(applyActivityAdjustment(targets, bmr: 1700, adjustment: -200).kcal, 1800)
    }

    func testATargetAlreadyBelowTheBmrIsNotRaisedByALoweringAdjustment() {
        XCTAssertEqual(applyActivityAdjustment(DayTargets(1500, MacroGoals(100, 150, 50)), bmr: 1700, adjustment: -100).kcal, 1500)
    }
}
