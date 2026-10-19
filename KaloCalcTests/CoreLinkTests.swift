import XCTest
import KaloCalcCore
@testable import KaloCalc

final class CoreLinkTests: XCTestCase {
    func testEveryTabHasAnIcon() {
        for tab in AppTab.allCases { XCTAssertFalse(tab.systemImage.isEmpty); XCTAssertFalse(tab.title.isEmpty) }
    }
}
