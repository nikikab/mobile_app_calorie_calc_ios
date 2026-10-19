import Foundation

public struct HTTPRequest: Equatable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval

    public init(url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval = 15) {
        self.url = url; self.method = method; self.headers = headers; self.body = body; self.timeout = timeout
    }
}

public struct HTTPResponse: Equatable {
    public var status: Int
    public var body: Data
    public init(status: Int, body: Data) { self.status = status; self.body = body }
    public var text: String { String(decoding: body, as: UTF8.self) }
}

/// Sends a request and returns whatever status came back; throws only when there was no answer at all.
/// The app backs it with URLSession; tests use a fake.
public protocol HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public enum NetworkError: Error, Equatable {
    case http(Int)
}

/// Percent-encodes a value for a query string or a path segment (everything except letters, digits and `-._~`).
func urlEncode(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? ""
}
