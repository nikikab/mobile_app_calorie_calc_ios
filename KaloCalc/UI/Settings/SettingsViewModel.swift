import Foundation
import Observation
import KaloCalcCore

@MainActor
@Observable
final class SettingsViewModel {
    private let model: AppModel
    private let transport: HTTPTransport

    /// What is saved; the key field below may differ until "Save key" is tapped.
    private(set) var gemini: GeminiSettings
    var key: String
    var keyVisible = false
    private(set) var scanInvalid = false
    private(set) var testing = false
    private(set) var testResult: String?

    init(model: AppModel, transport: HTTPTransport = URLSessionTransport()) {
        self.model = model
        self.transport = transport
        let g = model.settingsStore.gemini
        gemini = g
        key = g.apiKey
    }

    var dirty: Bool { key.trimmingCharacters(in: .whitespacesAndNewlines) != gemini.apiKey }
    var canClear: Bool { gemini.enabled || !key.isEmpty }
    var canTest: Bool { !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !testing }

    func saveKey() {
        model.settingsStore.saveKey(key)
        refresh()
        key = gemini.apiKey
    }

    func clearKey() {
        key = ""
        saveKey()
        testResult = nil
    }

    /// Takes the text of a scanned QR code as the key, if it looks like one.
    func scanned(_ raw: String) {
        if let cleaned = cleanApiKey(raw) { key = cleaned; scanInvalid = false } else { scanInvalid = true }
    }

    func startScan() { scanInvalid = false }

    func selectModel(_ name: String) {
        model.settingsStore.saveModel(name)
        refresh()
    }

    func addModel(_ raw: String) {
        model.settingsStore.addCustomModel(raw)
        refresh()
    }

    func removeModel(_ name: String) {
        model.settingsStore.removeCustomModel(name)
        refresh()
    }

    func test() async {
        guard canTest else { return }
        testing = true
        testResult = nil
        let d = await GeminiClient(transport).diagnose(apiKey: key.trimmingCharacters(in: .whitespacesAndNewlines), model: gemini.model)
        testResult = report(for: d)
        testing = false
    }

    /// Fills in a report without going to the network, for screenshots.
    func loadDemo() {
        key = "AIzaSyDemoKeyDemoKeyDemoKey0123456"
        saveKey()
        testResult = report(for: GeminiDiagnosis(models: ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-3-pro"],
                                                 keyError: nil, model: gemini.model, modelWorks: true, modelError: nil))
    }

    private func refresh() { gemini = model.settingsStore.gemini }
}
