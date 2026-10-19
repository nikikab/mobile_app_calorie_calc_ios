import XCTest
@testable import KaloCalcCore

final class FakeTransport: HTTPTransport {
    var sent: [HTTPRequest] = []
    var replies: [(Int, String)]
    init(_ replies: [(Int, String)]) { self.replies = replies }
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        sent.append(request)
        let (status, body) = replies.count > 1 ? replies.removeFirst() : replies[0]
        return HTTPResponse(status: status, body: Data(body.utf8))
    }
}

final class OpenFoodFactsClientTests: XCTestCase {
    func testSearchEncodesTheQueryAndIdentifiesTheApp() async throws {
        let t = FakeTransport([(200, #"{"hits":[{"product_name":"Мляко","nutriments":{"energy-kcal_100g":47}}]}"#)])
        let r = try await OpenFoodFactsClient(t).search("мляко & сирене")
        XCTAssertEqual(r.map(\.name), ["Мляко"])
        let url = t.sent[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("https://search.openfoodfacts.org/search?q=%D0%BC"), url)
        XCTAssertTrue(url.contains("%20%26%20"), url)
        XCTAssertTrue(url.contains("page_size=25"))
        XCTAssertEqual(t.sent[0].headers["User-Agent"], "KaloCalc/0.1 (iOS)")
    }

    func testBarcodeLookup() async throws {
        let t = FakeTransport([(200, #"{"status":1,"product":{"product_name":"Хляб","brands":"A, B","nutriments":{"energy-kcal_100g":250}}}"#)])
        let p = try await OpenFoodFactsClient(t).byBarcode("3017620422003")
        XCTAssertEqual(p?.brand, "A")
        XCTAssertEqual(t.sent[0].url.absoluteString,
                       "https://world.openfoodfacts.org/api/v2/product/3017620422003.json?fields=product_name,brands,nutriments")
    }

    func testUnknownBarcodeIsNil() async throws {
        let t = FakeTransport([(200, #"{"status":0}"#)])
        let p = try await OpenFoodFactsClient(t).byBarcode("0")
        XCTAssertNil(p)
    }

    func testNon200IsAnError() async {
        let t = FakeTransport([(503, "")])
        do { _ = try await OpenFoodFactsClient(t).search("x"); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? NetworkError, .http(503)) }
    }
}

final class GeminiClientTests: XCTestCase {
    /// A generateContent response whose first part holds `text`.
    func answer(_ text: String) -> String {
        let response: [String: Any] = ["candidates": [["content": ["parts": [["text": text]]]]]]
        return String(decoding: try! JSONSerialization.data(withJSONObject: response), as: UTF8.self)
    }

    func body(_ r: HTTPRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(r.body)) as? [String: Any])
    }

    func testEstimateSendsTheKeyInAHeaderAndThePhotoAsBase64() async throws {
        let t = FakeTransport([(200, answer(#"[{"name":"Ябълка","grams":150,"kcal":78,"protein_g":0.4,"carbs_g":20,"fat_g":0.2,"ingredients":[]}]"#))])
        let r = try await GeminiClient(t).estimate(apiKey: "KEY", model: "gemini-x", jpeg: Data([1, 2, 3]), language: "Bulgarian")
        XCTAssertEqual(r.map(\.name), ["Ябълка"])
        let req = t.sent[0]
        XCTAssertEqual(req.url.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models/gemini-x:generateContent")
        XCTAssertFalse(req.url.absoluteString.contains("KEY"))
        XCTAssertEqual(req.headers["x-goog-api-key"], "KEY")
        XCTAssertEqual(req.method, "POST")
        let parts = try XCTUnwrap(((body(req)["contents"] as? [[String: Any]])?[0]["parts"]) as? [[String: Any]])
        XCTAssertTrue((parts[0]["text"] as? String)?.contains("Give names in Bulgarian.") == true)
        XCTAssertEqual((parts[1]["inline_data"] as? [String: Any])?["data"] as? String, "AQID")
        let config = try XCTUnwrap(body(req)["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["responseMimeType"] as? String, "application/json")
        let items = try XCTUnwrap((config["responseSchema"] as? [String: Any])?["items"] as? [String: Any])
        XCTAssertEqual(items["required"] as? [String], ["name", "grams", "kcal", "protein_g", "carbs_g", "fat_g", "ingredients"])
    }

    func testBadModelNameNeverReachesTheNetwork() async {
        let t = FakeTransport([(200, "")])
        do { _ = try await GeminiClient(t).estimate(apiKey: "k", model: "../x", jpeg: Data(), language: "French"); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? GeminiError, .badModel("../x")) }
        XCTAssertTrue(t.sent.isEmpty)
    }

    func testTranslateKeepsOrderAndRejectsAWrongCount() async throws {
        let ok = FakeTransport([(200, answer(#"["lait","pain"]"#))])
        let r = try await GeminiClient(ok).translate(apiKey: "k", model: "m", texts: ["мляко", "хляб"], from: "Bulgarian", to: "French")
        XCTAssertEqual(r, ["lait", "pain"])
        let short = FakeTransport([(200, answer(#"["lait"]"#))])
        do { _ = try await GeminiClient(short).translate(apiKey: "k", model: "m", texts: ["a", "b"], from: "A", to: "B"); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? GeminiError, .garbled) }
    }

    func testTranslatingNothingMakesNoRequest() async throws {
        let t = FakeTransport([(200, "")])
        let r = try await GeminiClient(t).translate(apiKey: "k", model: "m", texts: [], from: "A", to: "B")
        XCTAssertEqual(r, [])
        XCTAssertTrue(t.sent.isEmpty)
    }

    func testStatusCodesBecomeSpecificErrors() async {
        func failure(_ status: Int, _ body: String = "", model: String = "m") async -> GeminiError? {
            let t = FakeTransport([(status, body)])
            do { _ = try await GeminiClient(t).translate(apiKey: "k", model: model, texts: ["a"], from: "A", to: "B"); return nil }
            catch { return error as? GeminiError }
        }
        let a = await failure(404), b = await failure(429), c = await failure(503)
        let d = await failure(403, #"{"error":{"message":"API key not valid"}}"#), e = await failure(418)
        XCTAssertEqual(a, .modelMissing("m"))
        XCTAssertEqual(b, .rateLimited)
        XCTAssertEqual(c, .overloaded)
        XCTAssertEqual(d, .http(code: 403, detail: "API key not valid"))
        XCTAssertEqual(e, .http(code: 418, detail: nil))
    }

    func testDiagnoseReportsKeyAndModelSeparately() async {
        let list = #"{"models":[{"name":"models/gemini-pro","supportedGenerationMethods":["generateContent"]},{"name":"models/gemini-flash","supportedGenerationMethods":["generateContent"]},{"name":"models/embed","supportedGenerationMethods":["embedContent"]}]}"#
        let t = FakeTransport([(200, list), (404, "")])
        let d = await GeminiClient(t).diagnose(apiKey: "k", model: "gone")
        XCTAssertEqual(d.models, ["gemini-pro", "gemini-flash"])
        XCTAssertEqual(d.shownModels, ["gemini-flash", "gemini-pro"])
        XCTAssertNil(d.keyError)
        XCTAssertFalse(d.modelWorks)
        XCTAssertEqual(d.modelError as? GeminiError, .modelMissing("gone"))
        XCTAssertEqual(t.sent[0].method, "GET")
    }

    func testDiagnoseWithARejectedKey() async {
        let t = FakeTransport([(403, #"{"error":{"message":"bad key"}}"#)])
        let d = await GeminiClient(t).diagnose(apiKey: "k", model: "m")
        XCTAssertNil(d.models)
        XCTAssertEqual(d.keyError as? GeminiError, .http(code: 403, detail: "bad key"))
        XCTAssertFalse(d.modelWorks)
    }
}
