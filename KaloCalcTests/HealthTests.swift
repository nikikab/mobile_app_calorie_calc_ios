import XCTest
import KaloCalcCore
@testable import KaloCalc

@MainActor
final class FakeHealth: HealthSync {
    var isAvailable = true
    var allowWrite = true
    var written: [FoodEntry] = []
    var deleted: [Int64] = []
    var burned: Double?
    func requestWriteAccess() async -> Bool { allowWrite }
    func requestActivityAccess() async -> Bool { true }
    func write(_ entries: [FoodEntry]) async throws { written += entries }
    func delete(entryId: Int64) async { deleted.append(entryId) }
    func activeKcal(epochDay: Int64) async -> Double? { burned }
}

@MainActor
final class HealthTests: XCTestCase {
    var health: FakeHealth!
    var model: AppModel!
    var vm: DiaryViewModel!

    override func setUp() {
        health = FakeHealth()
        model = .inMemory(health: health)
        vm = DiaryViewModel(model: model)
    }

    private func values(_ name: String = "Soup") -> EntryValues {
        EntryValues(meal: .lunch, name: name, grams: 250, kcal: 120, proteinG: 5, carbsG: 10, fatG: 2)
    }

    private func settle() async { for _ in 0..<5 { await Task.yield() } }

    func testNothingIsWrittenWhileSyncIsOff() async {
        vm.add(values())
        await settle()
        XCTAssertTrue(health.written.isEmpty)
    }

    func testAnAddedEntryIsWrittenWithItsStoredId() async {
        model.settingsStore.saveHealthSync(true)
        vm.add(values())
        await settle()
        XCTAssertEqual(health.written.map(\.name), ["Soup"])
        XCTAssertEqual(health.written[0].id, vm.entries[0].id)
        XCTAssertNotEqual(health.written[0].id, 0)
    }

    func testAnEditIsWrittenAgainUnderTheSameId() async {
        model.settingsStore.saveHealthSync(true)
        vm.add(values())
        await settle()
        vm.update(vm.entries[0], with: values("Stew"))
        await settle()
        XCTAssertEqual(health.written.map(\.name), ["Soup", "Stew"])
        XCTAssertEqual(Set(health.written.map(\.id)).count, 1)
    }

    func testADeleteReachesHealthEvenIfSyncWasSwitchedOff() async {
        vm.add(values())
        let id = vm.entries[0].id
        vm.delete(vm.entries[0])
        await settle()
        XCTAssertEqual(health.deleted, [id])
    }

    func testBurnedCaloriesMoveTodaysTargetOnlyWhenSwitchedOn() async {
        let usual = vm.summary.targetKcal
        health.burned = expectedActiveKcal(model.profileStore.profile) + 1000
        await vm.refreshActivity()
        XCTAssertEqual(vm.summary.targetKcal, usual)
        model.settingsStore.saveActivityAdjust(true)
        await vm.refreshActivity()
        XCTAssertGreaterThan(vm.summary.targetKcal, usual)
        XCTAssertNotNil(vm.summary.activity)
        model.settingsStore.saveActivityAdjust(false)
        await vm.refreshActivity()
        XCTAssertEqual(vm.summary.targetKcal, usual)
    }

    func testSettingsDenialKeepsSyncOffAndSaysWhy() async {
        health.allowWrite = false
        let settings = SettingsViewModel(model: model)
        await settings.setHealthSync(true)
        XCTAssertFalse(settings.healthSync)
        XCTAssertFalse(model.settingsStore.healthSync)
        XCTAssertNotNil(settings.healthMessage)
    }

    func testSyncPastWritesEveryEntry() async {
        vm.add(values("A")); vm.add(values("B"))
        let settings = SettingsViewModel(model: model)
        await settings.setHealthSync(true)
        await settings.syncPastEntries()
        XCTAssertEqual(health.written.map(\.name).sorted(), ["A", "B"])
        XCTAssertNotNil(settings.healthMessage)
    }
}
