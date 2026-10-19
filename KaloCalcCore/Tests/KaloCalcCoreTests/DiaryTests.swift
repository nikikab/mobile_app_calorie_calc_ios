import XCTest
@testable import KaloCalcCore

final class DiaryTests: XCTestCase {
    let toast = FoodEntry(id: 3, epochDay: 20000, meal: .lunch, name: "Toast", kcal: 550,
                          proteinG: 30, carbsG: 40, fatG: 25, grams: 220)

    func testEverythingScalesWithTheWeight() throws {
        let half = try XCTUnwrap(toast.scaled(to: 110))
        XCTAssertEqual(half.kcal, 275)
        XCTAssertEqual(half.proteinG, 15, accuracy: 0.001)
        XCTAssertEqual(half.carbsG, 20, accuracy: 0.001)
        XCTAssertEqual(half.fatG, 12.5, accuracy: 0.001)
        XCTAssertEqual(half.grams, 110, accuracy: 0.001)
    }

    func testOtherFieldsStayAsTheyWere() throws {
        let bigger = try XCTUnwrap(toast.scaled(to: 330))
        XCTAssertEqual(bigger.kcal, 825)
        XCTAssertEqual(bigger.id, toast.id); XCTAssertEqual(bigger.name, toast.name); XCTAssertEqual(bigger.meal, toast.meal)
    }

    func testKcalIsRoundedToWholeNumbers() {
        var e = toast; e.kcal = 500; e.grams = 300
        XCTAssertEqual(e.scaled(to: 100)?.kcal, 167)
    }

    func testNothingToScaleFromWithoutAStoredWeightOrWithNonPositiveWeight() {
        var e = toast; e.grams = 0
        XCTAssertNil(e.scaled(to: 100))
        XCTAssertNil(toast.scaled(to: 0)); XCTAssertNil(toast.scaled(to: -5))
    }

    func testMealByHour() {
        for h in [5, 10] { XCTAssertEqual(Meal.forHour(h), .breakfast) }
        for h in [11, 14] { XCTAssertEqual(Meal.forHour(h), .lunch) }
        for h in [18, 21] { XCTAssertEqual(Meal.forHour(h), .dinner) }
        for h in [15, 17, 22, 0, 4] { XCTAssertEqual(Meal.forHour(h), .snack) }
    }

    func testEntryTimeIsNowForTodayAndMiddayOtherwise() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Sofia")!
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let today = epochDay(of: now, calendar: cal)
        XCTAssertEqual(entryTimeMillis(epochDay: today, now: now, calendar: cal), 1_760_000_000_000)
        let ms = entryTimeMillis(epochDay: today - 1, now: now, calendar: cal)
        let d = Date(timeIntervalSince1970: Double(ms) / 1000)
        XCTAssertEqual(cal.component(.hour, from: d), 12)
        XCTAssertEqual(epochDay(of: d, calendar: cal), today - 1)
    }

    func testEpochDayOfKnownDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(epochDay(of: Date(timeIntervalSince1970: 86400 * 20000 + 3600), calendar: cal), 20000)
    }

    func testEntryWithoutStoredTimeStartsAtMidday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(toast.startDate(calendar: cal).timeIntervalSince1970, 86400 * 20000 + 12 * 3600)
    }
}
