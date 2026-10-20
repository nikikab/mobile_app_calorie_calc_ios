import XCTest
@testable import KaloCalcCore

final class ProgressTests: XCTestCase {
    func testWeekHasSevenDaysOldestFirstWithGaps() {
        let bars = weekBars(endingOn: 100, kcalByDay: [100: 1800, 98: 2000])
        XCTAssertEqual(bars.map(\.epochDay), Array(94...100))
        XCTAssertEqual(bars.map(\.kcal), [nil, nil, nil, nil, 2000, nil, 1800])
    }

    func testWeightInputRangeAndComma() {
        XCTAssertEqual(parseWeightInput("72,5"), 72.5)
        XCTAssertEqual(parseWeightInput(" 80 "), 80)
        XCTAssertNil(parseWeightInput("29.9"))
        XCTAssertNil(parseWeightInput("301"))
        XCTAssertNil(parseWeightInput("abc"))
        XCTAssertNil(parseWeightInput(""))
    }

    func testTrend() {
        XCTAssertNil(weightTrend([]))
        XCTAssertEqual(weightTrend([WeightEntry(epochDay: 1, kg: 70)]), WeightTrend(latest: 70, change: nil, count: 1))
        let t = weightTrend([WeightEntry(epochDay: 1, kg: 72), WeightEntry(epochDay: 5, kg: 70.5)])
        XCTAssertEqual(t?.latest, 70.5)
        XCTAssertEqual(t?.change ?? 0, -1.5, accuracy: 1e-9)
        XCTAssertEqual(t?.count, 2)
    }

    func testAverageIgnoresEmptyDays() {
        XCTAssertNil(averageKcal(weekBars(endingOn: 10, kcalByDay: [:])))
        XCTAssertEqual(averageKcal(weekBars(endingOn: 10, kcalByDay: [10: 2000, 9: 1501])), 1751)
    }
}
