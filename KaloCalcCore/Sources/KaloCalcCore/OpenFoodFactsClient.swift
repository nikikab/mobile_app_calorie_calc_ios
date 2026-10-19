import Foundation

public struct OpenFoodFactsClient {
    private static let base = "https://world.openfoodfacts.org"
    // The legacy cgi/search.pl endpoint is often unavailable; search-a-licious is the supported search API.
    private static let search = "https://search.openfoodfacts.org/search"
    private static let fields = "product_name,brands,nutriments"

    private let transport: HTTPTransport
    public init(_ transport: HTTPTransport) { self.transport = transport }

    public func search(_ query: String) async throws -> [Product] {
        try parseSearch(await get("\(Self.search)?q=\(urlEncode(query))&page_size=25&fields=\(Self.fields)"))
    }

    /// Nil when the barcode is unknown or the product has no usable nutrition data.
    public func byBarcode(_ code: String) async throws -> Product? {
        try parseBarcode(await get("\(Self.base)/api/v2/product/\(urlEncode(code)).json?fields=\(Self.fields)"))
    }

    private func get(_ url: String) async throws -> String {
        guard let u = URL(string: url) else { throw NetworkError.http(0) }
        // Open Food Facts asks API clients to identify themselves.
        let r = try await transport.send(HTTPRequest(url: u, headers: ["User-Agent": "KaloCalc/0.1 (iOS)"], timeout: 15))
        guard r.status == 200 else { throw NetworkError.http(r.status) }
        return r.text
    }
}
