import XCTest
@testable import KaloCalcCore

final class HelpUrlTests: XCTestCase {
    private let scenario = "10-language-and-settings"

    func testTranslatedLanguagesOpenTheirOwnGuide() {
        for l in [AppLanguage.bg, .de, .fr, .es] {
            XCTAssertTrue(l.helpUrl().hasSuffix("/README.\(l.code)"))
            XCTAssertTrue(l.helpUrl(scenario: scenario).hasSuffix("/docs/\(l.code)/\(scenario)"))
        }
    }

    func testEnglishOpensTheDefaultGuide() {
        XCTAssertTrue(AppLanguage.en.helpUrl().hasSuffix("/mobile_app_calorie_calc_howto/"))
        XCTAssertTrue(AppLanguage.en.helpUrl(scenario: scenario).hasSuffix("/docs/en/\(scenario)"))
    }

    func testLinksPointToGitHubPages() {
        for l in AppLanguage.allCases {
            XCTAssertTrue(l.helpUrl().hasPrefix("https://nikikab.github.io/mobile_app_calorie_calc_howto/"))
        }
    }
}
