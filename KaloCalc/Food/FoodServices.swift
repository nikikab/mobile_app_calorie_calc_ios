import Foundation
import KaloCalcCore

/// What the search screen needs from the outside world; tests replace it.
struct FoodServices {
    var transport: HTTPTransport
    /// Labels for the photo at the given file, best first.
    var recognize: (URL) async -> [FoodLabel]

    static let live = FoodServices(transport: URLSessionTransport(), recognize: FoodRecognizer.labels(in:))
}

extension AppLanguage {
    /// The language picked in Settings, else the system's (English when the app isn't translated into it).
    static var current: AppLanguage { AppStrings.language }
}
