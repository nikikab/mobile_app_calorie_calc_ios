import XCTest
import KaloCalcCore
@testable import KaloCalc

/// Answers every request from `handler` instead of the network.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let (status, data) = Self.handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class URLSessionTransportTests: XCTestCase {
    var transport: URLSessionTransport!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        transport = URLSessionTransport(session: URLSession(configuration: config))
    }

    func testSendsMethodHeadersAndAnswersWithStatusAndBody() async throws {
        StubProtocol.handler = { _ in (200, Data("hello".utf8)) }
        let r = try await transport.send(HTTPRequest(url: URL(string: "https://example.com/x")!, method: "GET",
                                                     headers: ["x-goog-api-key": "K"]))
        XCTAssertEqual(r.status, 200)
        XCTAssertEqual(r.text, "hello")
        XCTAssertEqual(StubProtocol.lastRequest?.value(forHTTPHeaderField: "x-goog-api-key"), "K")
        XCTAssertEqual(StubProtocol.lastRequest?.httpMethod, "GET")
    }

    func testAnErrorStatusIsReturnedNotThrown() async throws {
        StubProtocol.handler = { _ in (429, Data()) }
        let r = try await transport.send(HTTPRequest(url: URL(string: "https://example.com")!))
        XCTAssertEqual(r.status, 429)
    }

    func testTheClientsWorkOverTheRealTransport() async throws {
        StubProtocol.handler = { _ in (200, Data(#"{"status":1,"product":{"product_name":"Хляб","nutriments":{"energy-kcal_100g":250}}}"#.utf8)) }
        let p = try await OpenFoodFactsClient(transport).byBarcode("123")
        XCTAssertEqual(p?.name, "Хляб")
    }
}

final class ErrorMessagesTests: XCTestCase {
    func testGeminiErrorsReadInEnglishWithTheirArguments() {
        XCTAssertEqual(userMessage(for: GeminiError.badModel("x y")), "Invalid model name: “x y”.")
        XCTAssertEqual(userMessage(for: GeminiError.rateLimited), "Gemini's free limit is used up. Try again later.")
        XCTAssertEqual(userMessage(for: GeminiError.modelMissing("m1")), "Model “m1” was not found. Change it in Settings.")
        XCTAssertEqual(userMessage(for: GeminiError.http(code: 403, detail: "no")), "HTTP 403: no")
        XCTAssertEqual(userMessage(for: GeminiError.http(code: 401, detail: nil)), "HTTP 401: invalid credentials")
        XCTAssertEqual(userMessage(for: GeminiError.http(code: 400, detail: nil)), "HTTP 400: request rejected (check the key)")
        XCTAssertEqual(userMessage(for: GeminiError.http(code: 418, detail: nil)), "HTTP 418: ")
    }

    func testPlainNetworkFailure() {
        XCTAssertEqual(userMessage(for: NetworkError.http(503)), "HTTP 503")
    }

    func testDiagnosisReport() {
        let ok = GeminiDiagnosis(models: ["gemini-pro", "gemini-flash"], keyError: nil, model: "gemini-flash", modelWorks: true, modelError: nil)
        XCTAssertEqual(report(for: ok), "✓ Key accepted. Models with generateContent: 2.\ngemini-flash, gemini-pro\n\n✓ Model gemini-flash responds.")
        let bad = GeminiDiagnosis(models: nil, keyError: GeminiError.http(code: 403, detail: "bad"), model: "m", modelWorks: false,
                                  modelError: GeminiError.rateLimited)
        XCTAssertEqual(report(for: bad), "✗ Key not accepted: HTTP 403: bad\n\n✗ Model m: Gemini's free limit is used up. Try again later.")
    }
}
