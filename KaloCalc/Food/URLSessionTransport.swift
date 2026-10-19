import Foundation
import KaloCalcCore

/// Sends `KaloCalcCore` requests with URLSession. Cancelling the calling task cancels the request.
struct URLSessionTransport: HTTPTransport {
    var session: URLSession = .shared

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var r = URLRequest(url: request.url, timeoutInterval: request.timeout)
        r.httpMethod = request.method
        r.httpBody = request.body
        for (name, value) in request.headers { r.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await session.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return HTTPResponse(status: http.statusCode, body: data)
    }
}
