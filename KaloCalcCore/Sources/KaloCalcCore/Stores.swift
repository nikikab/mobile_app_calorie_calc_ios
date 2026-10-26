import Foundation

/// Where small values are kept. The app backs it with UserDefaults; tests use `MemoryKeyValueStore`.
/// Reading a missing key gives nil.
public protocol KeyValueStore: AnyObject {
    func string(_ key: String) -> String?
    func int(_ key: String) -> Int?
    func double(_ key: String) -> Double?
    func bool(_ key: String) -> Bool?
    func set(_ value: String, for key: String)
    func set(_ value: Int, for key: String)
    func set(_ value: Double, for key: String)
    func set(_ value: Bool, for key: String)
}

/// For secrets such as the API key. The app backs it with the Keychain.
public protocol SecretStore: AnyObject {
    func secret(_ key: String) -> String?
    func setSecret(_ value: String?, for key: String)
}

public final class MemoryKeyValueStore: KeyValueStore, SecretStore {
    private var values: [String: Any] = [:]
    public init() {}
    public func string(_ key: String) -> String? { values[key] as? String }
    public func int(_ key: String) -> Int? { values[key] as? Int }
    public func double(_ key: String) -> Double? { values[key] as? Double }
    public func bool(_ key: String) -> Bool? { values[key] as? Bool }
    public func set(_ value: String, for key: String) { values[key] = value }
    public func set(_ value: Int, for key: String) { values[key] = value }
    public func set(_ value: Double, for key: String) { values[key] = value }
    public func set(_ value: Bool, for key: String) { values[key] = value }
    public func secret(_ key: String) -> String? { values[key] as? String }
    public func setSecret(_ value: String?, for key: String) { values[key] = value }
}

/// The user's profile and the selected goal. Keys and values match the Android DataStore ("profile").
public final class ProfileStore {
    private enum K {
        static let sex = "sex", age = "age", height = "height", weight = "weight", activity = "activity"
        static let goal = "goal", insulinResistance = "insulin_resistance", activePlan = "active_plan"
    }
    private let store: KeyValueStore
    public init(_ store: KeyValueStore) { self.store = store }

    /// Unknown or missing values fall back to the defaults.
    public var profile: Profile {
        let d = Profile()
        return Profile(
            sex: store.string(K.sex).flatMap(Sex.init(rawValue:)) ?? d.sex,
            age: store.int(K.age) ?? d.age,
            heightCm: store.int(K.height) ?? d.heightCm,
            weightKg: store.double(K.weight) ?? d.weightKg,
            activity: store.string(K.activity).flatMap(ActivityLevel.init(rawValue:)) ?? d.activity,
            goal: store.string(K.goal).flatMap(Goal.init(rawValue:)) ?? d.goal,
            insulinResistance: store.bool(K.insulinResistance) ?? d.insulinResistance)
    }

    /// Id of the selected saved goal; 0 means none, i.e. the profile's default split.
    public var activePlanId: Int64 { Int64(store.int(K.activePlan) ?? 0) }

    public func setActivePlan(_ id: Int64) { store.set(Int(id), for: K.activePlan) }

    /// Picking one of the built-in goals (lose, maintain, gain) also deselects any saved goal.
    public func setBuiltInGoal(_ goal: Goal) {
        store.set(goal.rawValue, for: K.goal)
        store.set(0, for: K.activePlan)
    }

    /// Used when a weight is logged, so every goal is recalculated from the newest weight.
    public func setWeight(_ kg: Double) { store.set(kg, for: K.weight) }

    public func save(_ p: Profile) {
        store.set(p.sex.rawValue, for: K.sex)
        store.set(p.age, for: K.age)
        store.set(p.heightCm, for: K.height)
        store.set(p.weightKg, for: K.weight)
        store.set(p.activity.rawValue, for: K.activity)
        store.set(p.goal.rawValue, for: K.goal)
        store.set(p.insulinResistance, for: K.insulinResistance)
    }
}

/// The Gemini key (kept in the secret store), the chosen model and the user's own models.
public final class SettingsStore {
    private static let keyKey = "gemini_key", modelKey = "gemini_model", customKey = "gemini_custom_models", languageKey = "app_language", consentKey = "gemini_consent"
    private let store: KeyValueStore
    private let secrets: SecretStore
    public init(_ store: KeyValueStore, secrets: SecretStore) { self.store = store; self.secrets = secrets }

    public var gemini: GeminiSettings {
        GeminiSettings(
            apiKey: secrets.secret(Self.keyKey) ?? "",
            model: store.string(Self.modelKey).flatMap(normalizeModelName) ?? defaultGeminiModel,
            customModels: parseCustom(store.string(Self.customKey)))
    }

    /// The language picked in the app, or nil to follow the system.
    public var language: AppLanguage? { store.string(Self.languageKey).flatMap(AppLanguage.from(code:)) }

    public func saveLanguage(_ language: AppLanguage) { store.set(language.code, for: Self.languageKey) }

    /// Whether the user agreed to photos and search text being sent to Gemini. It belongs to the key: clearing the key
    /// takes the agreement back, so a new key asks again.
    public var geminiConsent: Bool { store.bool(Self.consentKey) ?? false }

    public func saveGeminiConsent(_ agreed: Bool) { store.set(agreed, for: Self.consentKey) }

    /// The settings to send requests with: without the user's agreement the key is left out, so nothing is sent.
    public var geminiForSending: GeminiSettings {
        var g = gemini
        if !geminiConsent { g.apiKey = "" }
        return g
    }

    public func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        secrets.setSecret(trimmed.isEmpty ? nil : trimmed, for: Self.keyKey)
        if trimmed.isEmpty { saveGeminiConsent(false) }
    }

    public func saveModel(_ model: String) {
        guard let name = normalizeModelName(model) else { return }
        store.set(name, for: Self.modelKey)
    }

    /// Adds `raw` to the user's models and selects it. Returns false if it isn't a valid model id.
    @discardableResult
    public func addCustomModel(_ raw: String) -> Bool {
        guard let name = normalizeModelName(raw) else { return false }
        let current = parseCustom(store.string(Self.customKey))
        if !presetGeminiModels.contains(name) && !current.contains(name) {
            store.set((current + [name]).joined(separator: ","), for: Self.customKey)
        }
        store.set(name, for: Self.modelKey)
        return true
    }

    /// Removes a user-added model; if it was selected, falls back to the default.
    public func removeCustomModel(_ name: String) {
        store.set(parseCustom(store.string(Self.customKey)).filter { $0 != name }.joined(separator: ","), for: Self.customKey)
        if store.string(Self.modelKey) == name { store.set(defaultGeminiModel, for: Self.modelKey) }
    }

    private func parseCustom(_ stored: String?) -> [String] {
        var seen = Set<String>()
        return (stored ?? "").split(separator: ",", omittingEmptySubsequences: false)
            .compactMap { normalizeModelName(String($0)) }.filter { seen.insert($0).inserted }
    }
}
