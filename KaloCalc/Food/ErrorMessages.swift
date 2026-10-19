import Foundation
import KaloCalcCore

/// The text to show the user for a failure: localized for our own errors, the system's description for anything else.
func userMessage(for error: Error) -> String {
    switch error {
    case let e as GeminiError: return message(for: e)
    case NetworkError.http(let code): return "HTTP \(code)"
    default: return error.localizedDescription
    }
}

private func message(for e: GeminiError) -> String {
    switch e {
    case .noCandidates: return AppStrings.text("gemini_no_candidates")
    case .empty: return AppStrings.text("gemini_empty")
    case .garbled: return AppStrings.text("gemini_garbled")
    case .badModel(let m): return AppStrings.text("gemini_bad_model", m)
    case .modelMissing(let m): return AppStrings.text("gemini_model_missing", m)
    case .rateLimited: return AppStrings.text("gemini_rate_limited")
    case .overloaded: return AppStrings.text("gemini_overloaded")
    case .http(let code, let detail):
        switch code {
        case 400, 403: return AppStrings.text("gemini_http_code", code, detail ?? AppStrings.text("gemini_default_rejected"))
        case 401: return AppStrings.text("gemini_http_code", code, detail ?? AppStrings.text("gemini_default_401"))
        default: return AppStrings.text("gemini_http_code", code, detail ?? "")
        }
    }
}

/// The two-line report shown by the "test the key" button in Settings.
func report(for d: GeminiDiagnosis) -> String {
    let key = d.models.map { AppStrings.text("gemini_diag_ok", $0.count, d.shownModels.joined(separator: ", ")) }
        ?? AppStrings.text("gemini_diag_fail", d.keyError.map(userMessage(for:)) ?? "")
    let model = d.modelWorks
        ? AppStrings.text("gemini_model_ok", d.model)
        : AppStrings.text("gemini_model_fail", d.model, d.modelError.map(userMessage(for:)) ?? "")
    return key + "\n\n" + model
}
