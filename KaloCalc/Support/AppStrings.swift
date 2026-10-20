import Foundation
import KaloCalcCore

/// Looks up a string from the catalog by its key (the Android resource name) and fills in `%1$lld` / `%1$@` arguments.
/// Code that has no SwiftUI environment (error messages, notifications) goes through here. `bundle` is the one place
/// to change when the language picker overrides the system language.
enum AppStrings {
    nonisolated(unsafe) static var bundle: Bundle = .main
    nonisolated(unsafe) private(set) static var language: AppLanguage = systemLanguage

    /// The system language, or English when the app isn't translated into it.
    static var systemLanguage: AppLanguage {
        AppLanguage.from(code: Locale.preferredLanguages.first.flatMap { Locale(identifier: $0).language.languageCode?.identifier }) ?? .en
    }

    /// Switches every string looked up through `text` to `language` (nil follows the system).
    static func use(_ language: AppLanguage?) {
        let chosen = language ?? systemLanguage
        self.language = chosen
        bundle = Bundle.main.path(forResource: chosen.code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    static func text(_ key: String, _ args: CVarArg...) -> String { text(key, args: args) }

    static func text(_ key: String, args: [CVarArg]) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return args.isEmpty ? format : String(format: format, arguments: args)
    }
}

/// Short form of `AppStrings.text` for use in views.
func tr(_ key: String, _ args: CVarArg...) -> String { AppStrings.text(key, args: args) }
