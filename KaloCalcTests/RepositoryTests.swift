import XCTest
import SwiftData
import KaloCalcCore
@testable import KaloCalc

@MainActor
final class RepositoryTests: XCTestCase {
    var container: ModelContainer!
    var counters: MemoryKeyValueStore!
    var repo: Repository!

    override func setUpWithError() throws {
        container = try Persistence.makeContainer(inMemory: true)
        counters = MemoryKeyValueStore()
        repo = Repository(context: container.mainContext, counters: counters)
    }

    private func entry(day: Int64 = 100, name: String = "Хляб", kcal: Int = 250, photo: String? = nil) -> FoodEntry {
        FoodEntry(epochDay: day, meal: .lunch, name: name, kcal: kcal, proteinG: 8, carbsG: 49, fatG: 3,
                  photoPath: photo, epochMillis: 1_000, grams: 100)
    }

    func testEntriesComeBackPerDayInInsertOrderWithTheirValues() throws {
        let a = try repo.insert(entry(name: "A"))
        let b = try repo.insert(entry(name: "B"))
        try repo.insert(entry(day: 101, name: "Other day"))
        let day = try repo.entries(forDay: 100)
        XCTAssertEqual(day.map(\.name), ["A", "B"])
        XCTAssertEqual(day.map(\.id), [a, b])
        XCTAssertEqual(day[0], { var e = entry(name: "A"); e.id = a; return e }())
    }

    func testIdsAreNeverReusedAfterDeletingTheLastEntry() throws {
        let first = try repo.insert(entry())
        try repo.deleteEntry(id: first)
        XCTAssertGreaterThan(try repo.insert(entry()), first)
    }

    func testUpdateChangesTheEntryInPlace() throws {
        var e = entry()
        e.id = try repo.insert(e)
        e.kcal = 400; e.meal = .dinner
        try repo.update(e)
        let stored = try repo.entries(forDay: 100)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].kcal, 400)
        XCTAssertEqual(stored[0].meal, .dinner)
    }

    func testDeleteAndDeleteAll() throws {
        let id = try repo.insert(entry())
        try repo.insert(entry(name: "Keep"))
        try repo.deleteEntry(id: id)
        XCTAssertEqual(try repo.allEntries().map(\.name), ["Keep"])
        try repo.deleteAllEntries()
        XCTAssertTrue(try repo.allEntries().isEmpty)
    }

    func testOnlyPhotographedEntriesHavePhotos() throws {
        try repo.insert(entry(name: "No photo"))
        try repo.insert(entry(name: "Old", photo: "a.jpg"))
        try repo.insert(entry(name: "New", photo: "b.jpg"))
        XCTAssertEqual(try repo.entriesWithPhoto().map(\.name), ["Old", "New"])
    }

    func testDailyKcalSumsPerDayWithinTheRange() throws {
        try repo.insert(entry(day: 10, kcal: 100))
        try repo.insert(entry(day: 10, kcal: 200))
        try repo.insert(entry(day: 12, kcal: 50))
        try repo.insert(entry(day: 20, kcal: 999))
        XCTAssertEqual(try repo.dailyKcal(from: 10, to: 12), [10: 300, 12: 50])
    }

    func testAnotherWeighInOnTheSameDayReplacesTheFirst() throws {
        try repo.upsertWeight(WeightEntry(epochDay: 5, kg: 80))
        try repo.upsertWeight(WeightEntry(epochDay: 5, kg: 79.4))
        try repo.upsertWeight(WeightEntry(epochDay: 3, kg: 81))
        XCTAssertEqual(try repo.allWeights(), [WeightEntry(epochDay: 3, kg: 81), WeightEntry(epochDay: 5, kg: 79.4)])
        XCTAssertEqual(try repo.weights(since: 4).map(\.epochDay), [5])
        try repo.deleteWeight(epochDay: 5)
        XCTAssertEqual(try repo.allWeights().map(\.epochDay), [3])
    }

    func testGoalPlansCrud() throws {
        var plan = GoalPlan(name: "Cut", kcal: 1800, proteinG: 150, carbsG: 150, fatG: 60, baseKcal: 2000)
        plan.id = try repo.insert(plan)
        plan.kcal = 1700
        try repo.update(plan)
        XCTAssertEqual(try repo.plans(), [plan])
        try repo.deletePlan(id: plan.id)
        XCTAssertTrue(try repo.plans().isEmpty)
    }

    func testDayTargetIsSetReplacedAndCleared() throws {
        XCTAssertNil(try repo.dayTarget(for: 7))
        try repo.setDayTarget(DayTarget(epochDay: 7, kcal: 1500))
        try repo.setDayTarget(DayTarget(epochDay: 7, kcal: 1600))
        XCTAssertEqual(try repo.dayTarget(for: 7)?.kcal, 1600)
        try repo.clearDayTarget(for: 7)
        XCTAssertNil(try repo.dayTarget(for: 7))
    }

    func testFavoritesAreSortedIgnoringCaseAndReplacedByName() throws {
        func fav(_ name: String, _ kcal: Int) -> Favorite {
            Favorite(name: name, grams: 100, kcal: kcal, proteinG: 1, carbsG: 2, fatG: 3)
        }
        try repo.saveFavorite(fav("banana", 90))
        try repo.saveFavorite(fav("Apple", 50))
        try repo.saveFavorite(fav("BANANA", 100))
        let all = try repo.favorites()
        XCTAssertEqual(all.map(\.name), ["Apple", "BANANA"])
        XCTAssertEqual(all[1].kcal, 100)
        try repo.deleteFavorite(id: all[0].id)
        XCTAssertEqual(try repo.favorites().map(\.name), ["BANANA"])
    }

    func testSchemaIsVersionOne() {
        XCTAssertEqual(KaloSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(KaloMigrationPlan.schemas.count, 1)
    }
}

final class DeviceStoresTests: XCTestCase {
    func testUserDefaultsStoreKeepsTypesApart() {
        let suite = "kalocalc.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        let s = UserDefaultsStore(d)
        XCTAssertNil(s.int("x"))
        s.set(3, for: "i"); s.set(2.5, for: "d"); s.set(true, for: "b"); s.set("t", for: "s")
        XCTAssertEqual(s.int("i"), 3)
        XCTAssertEqual(s.double("d"), 2.5)
        XCTAssertEqual(s.bool("b"), true)
        XCTAssertEqual(s.string("s"), "t")
        XCTAssertNil(s.string("i"))
    }

    func testProfileSurvivesARestartOfTheStore() {
        let suite = "kalocalc.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        let p = Profile(sex: .female, age: 33, heightCm: 170, weightKg: 64.5, activity: .moderate, goal: .lose, insulinResistance: true)
        ProfileStore(UserDefaultsStore(d)).save(p)
        XCTAssertEqual(ProfileStore(UserDefaultsStore(d)).profile, p)
    }
}
