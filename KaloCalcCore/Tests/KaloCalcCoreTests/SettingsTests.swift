import XCTest
@testable import KaloCalcCore

final class SettingsTests: XCTestCase {
    func testAcceptsNormalIds() {
        XCTAssertEqual(normalizeModelName("gemini-3.6-flash"), "gemini-3.6-flash")
        XCTAssertEqual(normalizeModelName("  gemini-2.5-flash-lite \n"), "gemini-2.5-flash-lite")
    }

    func testStripsModelsPrefix() { XCTAssertEqual(normalizeModelName("models/gemini-3.6-flash"), "gemini-3.6-flash") }

    func testRejectsAnythingThatCouldChangeTheUrl() {
        for s in ["", "  ", "a/b", "a?b=1", "a b", "../x", "a:generateContent", "-lead", "a#b", String(repeating: "a", count: 65)] {
            XCTAssertNil(normalizeModelName(s), "should reject '\(s)'")
        }
    }

    func testDefaultIsFirstPreset() {
        XCTAssertEqual(defaultGeminiModel, presetGeminiModels[0])
        XCTAssertEqual(presetGeminiModels[1], "gemini-3.1-flash-lite")
        XCTAssertEqual(defaultGeminiModel, "gemini-3.5-flash-lite")
    }

    func testAllModelsListsPresetsThenCustomWithoutDuplicates() {
        let s = GeminiSettings(model: "gemini-3.6-flash", customModels: ["gemini-3.6-flash", "my-model"])
        XCTAssertEqual(s.allModels, presetGeminiModels + ["gemini-3.6-flash", "my-model"])
        XCTAssertEqual(GeminiSettings(model: "legacy-model").allModels, presetGeminiModels + ["legacy-model"])
    }

    func testApiKey() {
        XCTAssertEqual(cleanApiKey("  AIzaSyA1234567890abcdefghij\n"), "AIzaSyA1234567890abcdefghij")
        XCTAssertNil(cleanApiKey("this is just a sentence with spaces in it"))
        XCTAssertNil(cleanApiKey("abc"))
        XCTAssertNil(cleanApiKey("   "))
    }

    func testLanguages() {
        XCTAssertEqual(AppLanguage.from(code: "bg"), .bg)
        XCTAssertNil(AppLanguage.from(code: "xx"))
        XCTAssertEqual(AppLanguage.fr.englishName, "French")
    }
}
