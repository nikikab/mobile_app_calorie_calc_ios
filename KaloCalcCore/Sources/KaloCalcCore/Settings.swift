import Foundation

/// Languages the app is translated into.
public enum AppLanguage: String, CaseIterable {
    case en, bg, de, fr, es

    public var code: String { rawValue }
    public var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .bg: return "🇧🇬"
        case .de: return "🇩🇪"
        case .fr: return "🇫🇷"
        case .es: return "🇪🇸"
        }
    }
    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .bg: return "Български"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }
    public var englishName: String {
        switch self {
        case .en: return "English"
        case .bg: return "Bulgarian"
        case .de: return "German"
        case .fr: return "French"
        case .es: return "Spanish"
        }
    }

    public static func from(code: String?) -> AppLanguage? { allCases.first { $0.code == code } }

    private static let helpBase = "https://nikikab.github.io/mobile_app_calorie_calc_howto"
    /// Languages the how-to site has a translation for; English is the default (the site root, and docs/en).
    private static let helpTranslated: Set<AppLanguage> = [.bg, .de, .fr, .es]

    /// The how-to guide in this language, or one of its pages; languages without a translated guide open the English one.
    public func helpUrl(scenario: String? = nil) -> String {
        let translated = Self.helpTranslated.contains(self)
        guard let scenario else { return translated ? "\(Self.helpBase)/README.\(code)" : "\(Self.helpBase)/" }
        return "\(Self.helpBase)/docs/\(translated ? code : "en")/\(scenario)"
    }
}

public let defaultGeminiModel = "gemini-3.5-flash-lite"
/// Models offered in the dropdown out of the box; the first is the default.
public let presetGeminiModels = [defaultGeminiModel, "gemini-3.1-flash-lite"]

public struct GeminiSettings: Equatable {
    public var apiKey: String
    public var model: String
    public var customModels: [String]

    public init(apiKey: String = "", model: String = defaultGeminiModel, customModels: [String] = []) {
        self.apiKey = apiKey; self.model = model; self.customModels = customModels
    }

    public var enabled: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Presets, then the user's own; the current model is always included so it never silently disappears.
    public var allModels: [String] {
        var seen = Set<String>()
        return (presetGeminiModels + customModels + [model]).filter { seen.insert($0).inserted }
    }
}

private func isAsciiAlnum(_ c: Character) -> Bool {
    guard let a = c.asciiValue else { return false }
    return (48...57).contains(a) || (65...90).contains(a) || (97...122).contains(a)
}

/// Cleans a user-typed Gemini model id, or returns nil if it can't be one. The id is placed in a URL path, so
/// anything beyond letters, digits, dot, dash and underscore is refused (no slashes, queries or spaces).
public func normalizeModelName(_ raw: String) -> String? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("models/") { s.removeFirst("models/".count) }
    guard (1...64).contains(s.count), let first = s.first, isAsciiAlnum(first) else { return nil }
    return s.allSatisfy { isAsciiAlnum($0) || $0 == "." || $0 == "-" || $0 == "_" } ? s : nil
}

/// Returns the API key contained in scanned or pasted `raw` text, or nil if it doesn't look like one.
/// Keys are a single token; anything with inner whitespace is rejected so a random QR code can't end up stored as a key.
public func cleanApiKey(_ raw: String) -> String? {
    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (20...400).contains(key.utf16.count), !key.contains(where: { $0.isWhitespace }) else { return nil }
    return key
}
