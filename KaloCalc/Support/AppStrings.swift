import Foundation

/// Looks up a string from the catalog by its key (the Android resource name) and fills in `%1$lld` / `%1$@` arguments.
/// Code that has no SwiftUI environment (error messages, notifications) goes through here. `bundle` is the one place
/// to change when the language picker overrides the system language.
enum AppStrings {
    nonisolated(unsafe) static var bundle: Bundle = .main

    static func text(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return args.isEmpty ? format : String(format: format, arguments: args)
    }
}
