import XCTest
@testable import KaloCalcCore

final class MeasureUnitTests: XCTestCase {
    func testParsesPlainAndDecimalNumbers() {
        XCTAssertEqual(parseAmount("50"), 50)
        XCTAssertEqual(parseAmount("1,5"), 1.5)
    }

    func testParsesFractionsAndMixedNumbers() {
        XCTAssertEqual(parseAmount("1/2"), 0.5)
        XCTAssertEqual(parseAmount("1 1/2"), 1.5)
    }

    func testRejectsNonsense() {
        for bad in ["", "abc", "1/0", "1/2 1", "1/2/3", "1 2 3"] { XCTAssertNil(parseAmount(bad), bad) }
    }

    func testConvertsMeasuresToGrams() {
        XCTAssertEqual(gramsFor(1, .tbsp, pieceGrams: nil), 15)
        XCTAssertEqual(gramsFor(0.5, .cup, pieceGrams: nil), 120)
        XCTAssertEqual(gramsFor(7, .piece, pieceGrams: 50), 350)
        XCTAssertNil(gramsFor(7, .piece, pieceGrams: nil))
        XCTAssertNil(gramsFor(nil, .g, pieceGrams: nil))
    }
}
