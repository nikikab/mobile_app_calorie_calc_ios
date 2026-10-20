import XCTest
import KaloCalcCore
@testable import KaloCalc

@MainActor
final class DiaryViewModelTests: XCTestCase {
    var model: AppModel!
    var vm: DiaryViewModel!

    override func setUp() {
        model = .inMemory()
        vm = DiaryViewModel(model: model)
    }

    private func values(_ name: String = "Soup", kcal: Int = 120, meal: Meal = .lunch) -> EntryValues {
        EntryValues(meal: meal, name: name, grams: 250, kcal: kcal, proteinG: 5, carbsG: 10, fatG: 2)
    }

    func testStartsOnTodayWithTheProfilesTarget() {
        XCTAssertTrue(vm.isToday)
        XCTAssertEqual(vm.summary.targetKcal, calculate(model.profileStore.profile).target)
        XCTAssertTrue(vm.entries.isEmpty)
    }

    func testAddedEntryShowsUpInItsMealAndTheTotals() {
        vm.add(values(kcal: 120, meal: .lunch))
        vm.add(values("Tea", kcal: 5, meal: .snack))
        XCTAssertEqual(vm.entries(for: .lunch).map(\.name), ["Soup"])
        XCTAssertEqual(vm.kcal(for: .lunch), 120)
        XCTAssertEqual(vm.summary.kcal, 125)
        XCTAssertGreaterThan(vm.entries[0].epochMillis, 0)
    }

    func testUpdateKeepsTheDayAndTimeButChangesTheValues() {
        vm.add(values())
        let original = vm.entries[0]
        vm.update(original, with: values("Stew", kcal: 300, meal: .dinner))
        let changed = vm.entries[0]
        XCTAssertEqual(changed.id, original.id)
        XCTAssertEqual(changed.name, "Stew")
        XCTAssertEqual(changed.kcal, 300)
        XCTAssertEqual(changed.meal, .dinner)
        XCTAssertEqual(changed.epochMillis, original.epochMillis)
        XCTAssertEqual(changed.epochDay, original.epochDay)
    }

    func testDeleteRemovesTheEntry() {
        vm.add(values())
        vm.delete(vm.entries[0])
        XCTAssertTrue(vm.entries.isEmpty)
    }

    func testShiftingTheDayShowsThatDaysEntries() {
        vm.add(values())
        vm.shiftDay(-1)
        XCTAssertFalse(vm.isToday)
        XCTAssertTrue(vm.entries.isEmpty)
        vm.add(values("Yesterday"))
        vm.shiftDay(1)
        XCTAssertEqual(vm.entries.map(\.name), ["Soup"])
    }

    func testEntryAddedToAnotherDayGetsMiddayOfThatDay() {
        vm.shiftDay(-3)
        vm.add(values())
        XCTAssertEqual(vm.entries[0].startDate(), middayDate(epochDay: vm.day))
    }

    func testDayTargetReplacesOnlyThatDay() {
        let usual = vm.summary.targetKcal
        vm.setDayTarget(1500)
        XCTAssertEqual(vm.summary.targetKcal, 1500)
        XCTAssertTrue(vm.summary.isCustomTarget)
        XCTAssertEqual(vm.summary.defaultKcal, usual)
        vm.shiftDay(1)
        XCTAssertEqual(vm.summary.targetKcal, usual)
        vm.shiftDay(-1)
        vm.clearDayTarget()
        XCTAssertEqual(vm.summary.targetKcal, usual)
    }

    func testUnusableDayTargetIsIgnored() {
        let usual = vm.summary.targetKcal
        vm.setDayTarget(0)
        vm.setDayTarget(maxPlanKcal + 1)
        XCTAssertEqual(vm.summary.targetKcal, usual)
    }

    func testSelectedPlanChangesTheTargetAfterReload() throws {
        let id = try model.repository.insert(GoalPlan(name: "P", kcal: 1700, proteinG: 120, carbsG: 150, fatG: 50, baseKcal: calculate(model.profileStore.profile).target))
        model.profileStore.setActivePlan(id)
        vm.reload()
        XCTAssertEqual(vm.summary.targetKcal, 1700)
    }

    func testFavoritesCanBeRemoved() throws {
        try model.repository.saveFavorite(Favorite(name: "Egg", grams: 60, kcal: 90, proteinG: 7, carbsG: 0, fatG: 6))
        vm.reload()
        XCTAssertEqual(vm.favorites.map(\.name), ["Egg"])
        vm.removeFavorite(vm.favorites[0])
        XCTAssertTrue(vm.favorites.isEmpty)
    }

    func testDemoDataFillsToday() {
        let demo = DiaryViewModel(model: .demo())
        XCTAssertEqual(demo.entries.count, 6)
        XCTAssertEqual(Set(demo.entries.map(\.meal)), Set(Meal.allCases))
        XCTAssertFalse(demo.favorites.isEmpty)
    }
}

@MainActor
final class CalculatorViewModelTests: XCTestCase {
    var model: AppModel!
    var vm: CalculatorViewModel!

    override func setUp() {
        model = .inMemory()
        vm = CalculatorViewModel(model: model)
    }

    func testFieldsStartFromTheSavedProfile() {
        XCTAssertEqual(vm.parsed, model.profileStore.profile)
        XCTAssertEqual(vm.result, calculate(model.profileStore.profile))
    }

    func testInvalidFieldsGiveNoResultAndCannotBeSaved() {
        vm.age = "5"
        XCTAssertNil(vm.parsed)
        XCTAssertNil(vm.result)
        let before = model.profileStore.profile
        vm.save()
        XCTAssertEqual(model.profileStore.profile, before)
        XCTAssertEqual(vm.currentTarget, calculate(before).target)
    }

    func testSaveWritesTheTypedProfile() {
        vm.sex = .female; vm.age = "40"; vm.weight = "61,5"; vm.activity = .high
        vm.save()
        let saved = model.profileStore.profile
        XCTAssertEqual(saved.sex, .female)
        XCTAssertEqual(saved.age, 40)
        XCTAssertEqual(saved.weightKg, 61.5)
        XCTAssertEqual(saved.activity, .high)
    }

    func testBuiltInGoalDeselectsThePlan() {
        vm.savePlan(GoalPlan(name: "P", kcal: 1800, proteinG: 100, carbsG: 150, fatG: 60, baseKcal: vm.currentTarget))
        XCTAssertNotEqual(vm.activePlanId, 0)
        vm.selectGoal(.gain)
        XCTAssertEqual(vm.activePlanId, 0)
        XCTAssertEqual(model.profileStore.profile.goal, .gain)
        XCTAssertEqual(model.profileStore.activePlanId, 0)
    }

    func testNewPlanBecomesTheSelectedGoalAndDrivesTheTargets() {
        vm.savePlan(GoalPlan(name: "Cut", kcal: 1800, proteinG: 100, carbsG: 150, fatG: 60, baseKcal: vm.currentTarget))
        XCTAssertEqual(vm.plans.map(\.name), ["Cut"])
        XCTAssertEqual(vm.activePlan?.name, "Cut")
        XCTAssertEqual(vm.targets.kcal, 1800)
        XCTAssertEqual(model.profileStore.activePlanId, vm.activePlanId)
    }

    func testEditingAPlanKeepsItSelected() {
        vm.savePlan(GoalPlan(name: "Cut", kcal: 1800, proteinG: 100, carbsG: 150, fatG: 60, baseKcal: vm.currentTarget))
        var plan = vm.plans[0]
        plan.kcal = 1700
        vm.savePlan(plan)
        XCTAssertEqual(vm.plans.count, 1)
        XCTAssertEqual(vm.targets.kcal, 1700)
        XCTAssertEqual(vm.activePlanId, plan.id)
    }

    func testDeletingTheSelectedPlanFallsBackToTheProfile() {
        vm.savePlan(GoalPlan(name: "Cut", kcal: 1800, proteinG: 100, carbsG: 150, fatG: 60, baseKcal: vm.currentTarget))
        vm.deletePlan(vm.plans[0])
        XCTAssertTrue(vm.plans.isEmpty)
        XCTAssertEqual(vm.activePlanId, 0)
        XCTAssertEqual(vm.targets.kcal, vm.currentTarget)
    }

    func testNewPlanDraftStartsFromTheNumbersInForce() {
        let d = vm.newPlanDraft()
        XCTAssertEqual(d.id, 0)
        XCTAssertEqual(d.kcal, vm.targets.kcal)
        XCTAssertEqual(d.baseKcal, vm.currentTarget)
    }
}

@MainActor
final class ProgressViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    func testLoggingWeightSavesItAndMovesTheProfileWeight() throws {
        let app = AppModel.inMemory()
        let vm = ProgressViewModel(model: app, today: { self.now })
        XCTAssertNil(vm.trend)
        vm.input = "70,4"
        vm.logWeight()
        XCTAssertEqual(vm.trend?.latest, 70.4)
        XCTAssertEqual(app.profileStore.profile.weightKg, 70.4)
        XCTAssertEqual(vm.input, "")
        vm.input = "71"
        vm.logWeight()
        XCTAssertEqual(vm.weights.count, 1, "the same day is replaced, not added")
        XCTAssertEqual(vm.trend?.latest, 71)
    }

    func testOutOfRangeWeightCannotBeLogged() {
        let vm = ProgressViewModel(model: .inMemory(), today: { self.now })
        vm.input = "5"
        XCTAssertNil(vm.kg)
        vm.logWeight()
        XCTAssertTrue(vm.weights.isEmpty)
    }

    func testWeekShowsDailyTotalsAndTheTarget() throws {
        let app = AppModel.inMemory()
        let day = epochDay(of: now)
        for (back, kcal) in [(0, 500), (0, 700), (3, 1800)] as [(Int, Int)] {
            _ = try app.repository.insert(FoodEntry(epochDay: day - Int64(back), meal: .lunch, name: "x", kcal: kcal))
        }
        let vm = ProgressViewModel(model: app, today: { self.now })
        XCTAssertEqual(vm.week.count, 7)
        XCTAssertEqual(vm.week.last?.kcal, 1200)
        XCTAssertEqual(vm.week[3].kcal, 1800)
        XCTAssertEqual(vm.average, 1500)
        XCTAssertEqual(vm.targetKcal, calculate(app.profileStore.profile).target)
    }
}
