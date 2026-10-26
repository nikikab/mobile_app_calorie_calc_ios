import XCTest
import KaloCalcCore
@testable import KaloCalc

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private let goodKey = "AIzaSyABCDEFGHIJKLMNOPQRSTUV"

    private func make(_ handler: @escaping (HTTPRequest) -> (Int, String) = { _ in (200, "{}") }) -> (SettingsViewModel, AppModel) {
        let app = AppModel.inMemory()
        return (SettingsViewModel(model: app, transport: StubTransport(handler)), app)
    }

    func testSavingAndClearingTheKey() {
        let (vm, app) = make()
        XCTAssertFalse(vm.dirty)
        vm.key = "  \(goodKey) "
        XCTAssertTrue(vm.dirty)
        vm.saveKey()
        XCTAssertTrue(vm.askingConsent, "a new key is only saved after the user agrees to what is sent to Gemini")
        XCTAssertFalse(app.settingsStore.gemini.enabled)
        vm.confirmConsent()
        XCTAssertFalse(vm.askingConsent)
        XCTAssertTrue(app.settingsStore.geminiConsent)
        XCTAssertEqual(app.settingsStore.gemini.apiKey, goodKey)
        XCTAssertEqual(vm.key, goodKey)
        XCTAssertFalse(vm.dirty)
        vm.clearKey()
        XCTAssertFalse(app.settingsStore.gemini.enabled)
        XCTAssertFalse(app.settingsStore.geminiConsent)
        XCTAssertFalse(vm.canClear)
    }

    func testScannedQrIsCheckedBeforeItBecomesTheKey() {
        let (vm, _) = make()
        vm.scanned("hello world")
        XCTAssertTrue(vm.scanInvalid)
        XCTAssertEqual(vm.key, "")
        vm.scanned(goodKey)
        XCTAssertFalse(vm.scanInvalid)
        XCTAssertEqual(vm.key, goodKey)
    }

    func testModelsAreSavedImmediately() {
        let (vm, app) = make()
        vm.addModel("gemini-9-test")
        XCTAssertEqual(vm.gemini.model, "gemini-9-test")
        XCTAssertTrue(vm.gemini.allModels.contains("gemini-9-test"))
        vm.selectModel(defaultGeminiModel)
        XCTAssertEqual(app.settingsStore.gemini.model, defaultGeminiModel)
        vm.removeModel("gemini-9-test")
        XCTAssertFalse(vm.gemini.allModels.contains("gemini-9-test"))
    }

    func testTestNeedsAKeyAndReportsBothChecks() async {
        let ok = #"{"models":[{"name":"models/gemini-x","supportedGenerationMethods":["generateContent"]}]}"#
        let (vm, _) = make { req in req.method == "GET" ? (200, ok) : (200, "{}") }
        XCTAssertFalse(vm.canTest)
        vm.key = goodKey
        await vm.test()
        let text = try? XCTUnwrap(vm.testResult)
        XCTAssertTrue(text?.contains("gemini-x") ?? false, text ?? "nil")
        XCTAssertFalse(vm.testing)
    }

    func testRejectedKeyIsReported() async {
        let (vm, _) = make { _ in (403, #"{"error":{"message":"API key not valid"}}"#) }
        vm.key = goodKey
        await vm.test()
        XCTAssertTrue(vm.testResult?.contains("API key not valid") ?? false, vm.testResult ?? "nil")
    }

    func testLanguageIsRememberedAndSwitchesStrings() {
        let app = AppModel.inMemory()
        app.setLanguage(.bg)
        XCTAssertEqual(app.language, .bg)
        XCTAssertEqual(app.settingsStore.language, .bg)
        XCTAssertEqual(AppLanguage.current, .bg)
        XCTAssertEqual(tr("tab_settings"), "Настройки")
        app.setLanguage(.en)
        XCTAssertEqual(tr("tab_settings"), "Settings")
    }
}
