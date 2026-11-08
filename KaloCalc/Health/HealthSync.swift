import Foundation
import HealthKit
import KaloCalcCore

/// What the app needs from Apple Health. The real one is `HealthKitSync`; tests and demo mode use `NoHealthSync`.
@MainActor
protocol HealthSync: AnyObject {
    var isAvailable: Bool { get }
    /// Asks to write nutrition; true when the user allowed it.
    func requestWriteAccess() async -> Bool
    /// Asks to read active energy. Apple does not say whether reading was refused, so this only reports that the sheet was shown.
    func requestActivityAccess() async -> Bool
    /// Inserts or replaces the samples for `entries`; each entry has a fixed id, so repeating is safe.
    func write(_ entries: [FoodEntry]) async throws
    func delete(entryId: Int64) async
    /// Active energy burned on the calendar day `epochDay`, or nil when nothing is recorded or reading isn't allowed.
    func activeKcal(epochDay: Int64) async -> Double?
}

@MainActor
final class NoHealthSync: HealthSync {
    var isAvailable: Bool { false }
    func requestWriteAccess() async -> Bool { false }
    func requestActivityAccess() async -> Bool { false }
    func write(_ entries: [FoodEntry]) async throws {}
    func delete(entryId: Int64) async {}
    func activeKcal(epochDay: Int64) async -> Double? { nil }
}

/// Writes diary entries to Apple Health as dietary samples and reads the day's active energy.
/// Food is write-only (nothing is read back, so other apps' entries can't be counted twice).
@MainActor
final class HealthKitSync: HealthSync {
    private let store = HKHealthStore()

    private static let nutrients: [(suffix: String, id: HKQuantityTypeIdentifier, unit: HKUnit)] = [
        ("kcal", .dietaryEnergyConsumed, .kilocalorie()),
        ("protein", .dietaryProtein, .gram()),
        ("carbs", .dietaryCarbohydrates, .gram()),
        ("fat", .dietaryFatTotal, .gram()),
    ]
    private static var shareTypes: Set<HKSampleType> { Set(nutrients.compactMap { HKQuantityType.quantityType(forIdentifier: $0.id) }) }
    private static var activeEnergy: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)! }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestWriteAccess() async -> Bool {
        guard isAvailable else { return false }
        do { try await store.requestAuthorization(toShare: Self.shareTypes, read: []) } catch { return false }
        // Writing is the one permission iOS reports back.
        return Self.shareTypes.allSatisfy { store.authorizationStatus(for: $0) == .sharingAuthorized }
    }

    func requestActivityAccess() async -> Bool {
        guard isAvailable else { return false }
        do { try await store.requestAuthorization(toShare: [], read: [Self.activeEnergy]); return true } catch { return false }
    }

    func write(_ entries: [FoodEntry]) async throws {
        guard !entries.isEmpty else { return }
        // The time as version makes a later write win over an earlier one.
        let version = Int(Date().timeIntervalSince1970 * 1000)
        var samples: [HKQuantitySample] = []
        for entry in entries {
            let start = entry.startDate()
            let base = clientRecordId(entryId: entry.id)
            let values = [Double(entry.kcal), entry.proteinG, entry.carbsG, entry.fatG]
            for (n, value) in zip(Self.nutrients, values) {
                guard let type = HKQuantityType.quantityType(forIdentifier: n.id) else { continue }
                samples.append(HKQuantitySample(
                    type: type, quantity: HKQuantity(unit: n.unit, doubleValue: max(value, 0)), start: start, end: start,
                    metadata: [HKMetadataKeySyncIdentifier: "\(base).\(n.suffix)", HKMetadataKeySyncVersion: version,
                               HKMetadataKeyFoodType: entry.name, "KaloCalcMeal": entry.meal.rawValue]))
            }
        }
        // HealthKit takes at most a few thousand objects comfortably per call.
        for chunk in stride(from: 0, to: samples.count, by: 1000).map({ Array(samples[$0..<min($0 + 1000, samples.count)]) }) {
            try await store.save(chunk)
        }
    }

    func delete(entryId: Int64) async {
        guard isAvailable else { return }
        let base = clientRecordId(entryId: entryId)
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                                    allowedValues: Self.nutrients.map { "\(base).\($0.suffix)" })
        for type in Self.shareTypes { _ = try? await store.deleteObjects(of: type, predicate: predicate) }
    }

    func activeKcal(epochDay: Int64) async -> Double? {
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: middayDate(epochDay: epochDay))
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.activeEnergy, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum)
        // The sum merges overlapping sources (phone and watch) by the user's priority order, so a step is not counted twice.
        return try? await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }
}
