import Foundation

/// What `GeminiClient.diagnose` found out: whether the key is accepted, and whether the chosen model answers.
public struct GeminiDiagnosis {
    /// Names of models that can generate content; nil when the key was not accepted.
    public var models: [String]?
    public var keyError: Error?
    /// The model id that was tried, or the text typed when it wasn't a valid id.
    public var model: String
    public var modelWorks: Bool
    public var modelError: Error?

    public init(models: [String]?, keyError: Error?, model: String, modelWorks: Bool, modelError: Error?) {
        self.models = models; self.keyError = keyError; self.model = model
        self.modelWorks = modelWorks; self.modelError = modelError
    }

    /// Flash models first, at most 12, for display.
    public var shownModels: [String] {
        let names = models ?? []
        return Array((names.filter { $0.contains("flash") } + names.filter { !$0.contains("flash") }).prefix(12))
    }
}

public struct GeminiClient {
    private static let base = "https://generativelanguage.googleapis.com/v1beta"

    private static func prompt(_ language: String) -> String {
        "Identify each distinct food or drink in this photo. For each, estimate the " +
        "portion weight in grams and the calories, protein, carbohydrates and fat for that whole portion. " +
        "Also list the main ingredients of each dish (for a single plain food, one ingredient is enough) with " +
        "their weight in grams and their own calories, protein, carbohydrates and fat; the ingredient weights " +
        "should add up to the portion weight. Give names in \(language). If the photo contains no food, return an empty array. These are rough estimates."
    }

    private static let numberFields = ["grams", "kcal", "protein_g", "carbs_g", "fat_g"]

    private static func objectSchema(_ extra: [String: Any] = [:]) -> [String: Any] {
        var props: [String: Any] = ["name": ["type": "STRING"]]
        for f in numberFields { props[f] = ["type": "NUMBER"] }
        for (k, v) in extra { props[k] = v }
        return ["type": "OBJECT", "properties": props, "required": ["name"] + numberFields + extra.keys.sorted()]
    }

    static let estimateSchema: [String: Any] = [
        "type": "ARRAY",
        "items": objectSchema(["ingredients": ["type": "ARRAY", "items": objectSchema()]]),
    ]

    private let transport: HTTPTransport
    public init(_ transport: HTTPTransport) { self.transport = transport }

    /// `language` is the English name of the language the item names should come back in, e.g. "Bulgarian".
    public func estimate(apiKey: String, model: String, jpeg: Data, language: String) async throws -> [FoodEstimate] {
        let id = try validModel(model)
        let body: [String: Any] = [
            "contents": [["parts": [
                ["text": Self.prompt(language)],
                ["inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
            ]]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": Self.estimateSchema],
        ]
        return try parseEstimates(await call("POST", "/models/\(id):generateContent", apiKey, body, model: id))
    }

    /// Translates `texts` (short food names) from `from` to `to`, both English language names; same order and size as the input.
    public func translate(apiKey: String, model: String, texts: [String], from: String, to: String) async throws -> [String] {
        if texts.isEmpty { return [] }
        let id = try validModel(model)
        let list = String(decoding: try JSONSerialization.data(withJSONObject: texts), as: UTF8.self)
        let instruction = "Translate each of these food names or food search terms from \(from) to \(to). " +
            "Return a JSON array of strings, one translation per input, in the same order. Keep brand names unchanged.\n" + list
        let body: [String: Any] = [
            "contents": [["parts": [["text": instruction]]]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": ["type": "ARRAY", "items": ["type": "STRING"]]],
        ]
        let response = try await call("POST", "/models/\(id):generateContent", apiKey, body, model: id)
        guard let out = parseTranslations(response, expected: texts.count) else { throw GeminiError.garbled }
        return out
    }

    /// Checks the key by listing models, then the chosen model with a tiny text-only request (it shows whether the
    /// model exists and has quota for this key). Never throws; failures are part of the result.
    public func diagnose(apiKey: String, model: String) async -> GeminiDiagnosis {
        var d = GeminiDiagnosis(models: nil, keyError: nil, model: model, modelWorks: false, modelError: nil)
        do {
            d.models = try parseModelNames(await call("GET", "/models?pageSize=200", apiKey, nil, model: nil))
        } catch {
            d.keyError = error
        }
        do {
            let id = try validModel(model)
            d.model = id
            let ping: [String: Any] = ["contents": [["parts": [["text": "Reply with: ok"]]]]]
            _ = try await call("POST", "/models/\(id):generateContent", apiKey, ping, model: id)
            d.modelWorks = true
        } catch {
            d.modelError = error
        }
        return d
    }

    private func validModel(_ model: String) throws -> String {
        guard let id = normalizeModelName(model) else { throw GeminiError.badModel(model) }
        return id
    }

    private func call(_ method: String, _ path: String, _ apiKey: String, _ body: [String: Any]?, model: String?) async throws -> String {
        guard let url = URL(string: Self.base + path) else { throw GeminiError.badModel(model ?? "") }
        // The key goes in a header, never the URL, so it can't leak into logs or error messages.
        var headers = ["x-goog-api-key": apiKey]
        var data: Data?
        if let body {
            headers["Content-Type"] = "application/json"
            data = try JSONSerialization.data(withJSONObject: body)
        }
        let r = try await transport.send(HTTPRequest(url: url, method: method, headers: headers, body: data, timeout: 60))
        if r.status == 200 { return r.text }
        let detail = ((try? parseJSON(r.text)) as? JSONObject).flatMap { ($0["error"] as? JSONObject)?["message"] as? String }
        switch r.status {
        case 404 where model != nil: throw GeminiError.modelMissing(model!)
        case 429: throw GeminiError.rateLimited
        case 500, 502, 503, 504: throw GeminiError.overloaded
        default: throw GeminiError.http(code: r.status, detail: detail)
        }
    }
}
