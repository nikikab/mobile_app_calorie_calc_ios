import Foundation

typealias JSONObject = [String: Any]

func parseJSON(_ text: String) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
}

/// Number or numeric string as a Double, like org.json's `optDouble`; `fallback` when absent or not numeric.
func optDouble(_ o: JSONObject, _ key: String, _ fallback: Double = 0) -> Double {
    switch o[key] {
    case let n as NSNumber: return n.doubleValue
    case let s as String: return Double(s.trimmingCharacters(in: .whitespaces)) ?? fallback
    default: return fallback
    }
}

func optString(_ o: JSONObject, _ key: String) -> String { (o[key] as? String) ?? "" }
