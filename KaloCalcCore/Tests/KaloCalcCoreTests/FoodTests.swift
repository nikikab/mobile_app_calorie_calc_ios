import XCTest
@testable import KaloCalcCore

final class OpenFoodFactsTests: XCTestCase {
    func testSearchSkipsProductsWithoutKcalOrName() throws {
        let json = """
        {"hits":[
            {"product_name":"Мляко","brands":["Верея","Друга"],"nutriments":{"energy-kcal_100g":47,"proteins_100g":3.3,"carbohydrates_100g":4.8,"fat_100g":1.5}},
            {"product_name":"Без данни","nutriments":{}},
            {"product_name":"","nutriments":{"energy-kcal_100g":10}}
        ]}
        """
        let r = try parseSearch(json)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].brand, "Верея")
        XCTAssertEqual(r[0].kcal100, 47)
        XCTAssertEqual(r[0].fat100, 1.5)
    }

    func testBarcodeBrandIsCommaSeparatedString() throws {
        let p = try parseBarcode(#"{"status":1,"product":{"product_name":"X","brands":"A,B","nutriments":{"energy-kcal_100g":1}}}"#)
        XCTAssertEqual(p?.brand, "A")
    }

    func testBarcodeNotFound() throws {
        XCTAssertNil(try parseBarcode(#"{"status":0,"status_verbose":"product not found"}"#))
    }

    func testBarcodeFound() throws {
        let p = try XCTUnwrap(parseBarcode(#"{"status":1,"product":{"product_name":"Хляб","nutriments":{"energy-kcal_100g":250}}}"#))
        XCTAssertEqual(p.name, "Хляб")
        XCTAssertEqual(p.protein100, 0)
    }
}

final class FoodSearchTests: XCTestCase {
    func p(_ name: String) -> Product { Product(name: name, brand: "Brand", kcal100: 100, protein100: 1, carbs100: 2, fat100: 3) }
    let key = GeminiSettings(apiKey: "k")
    var db: [String: [Product]] { ["lait": [p("Lait demi-écrémé"), p("Lait entier")]] }

    func fake(_ texts: [String], _ from: String, _ to: String) -> [String] {
        if to == "French" { return texts.map { $0 == "мляко" ? "lait" : $0 } }
        return texts.map { $0 == "Lait entier" ? "Прясно мляко" : "Полуобезмаслено мляко" }
    }

    func search(_ q: String, gemini: GeminiSettings? = nil, lang: AppLanguage = .bg,
                tr: (([String], String, String) async throws -> [String])? = nil) async throws -> [Product] {
        let d = db
        return try await FoodSearch.search(query: q, gemini: gemini ?? key, language: lang,
                                           plain: { d[$0] ?? [] }, translate: tr ?? { self.fake($0, $1, $2) })
    }

    struct Boom: Error {}

    func testDirectHitSkipsGemini() async throws {
        let r = try await search("lait", tr: { _, _, _ in throw Boom() })
        XCTAssertEqual(r.map(\.name), ["Lait demi-écrémé", "Lait entier"])
    }

    func testFallsBackToFrenchAndTranslatesNamesBack() async throws {
        let r = try await search("мляко")
        XCTAssertEqual(r.map(\.name), ["Полуобезмаслено мляко", "Прясно мляко"])
        XCTAssertEqual(r[0].brand, "Brand")
    }

    func testNoKeyMeansNoFallback() async throws {
        let r = try await search("мляко", gemini: GeminiSettings())
        XCTAssertTrue(r.isEmpty)
    }

    func testRandomForeignHitsAreReplacedByFrenchResults() async throws {
        let withNoise = db.merging(["мляко": [p("Milch"), p("Leche")]]) { $1 }
        let r = try await FoodSearch.search(query: "мляко", gemini: key, language: .bg,
            plain: { withNoise[$0] ?? [] },
            translate: { t, _, to in to == "French" ? t.map { $0 == "мляко" ? "lait" : $0 } : t.map { $0.replacingOccurrences(of: "Lait", with: "Мляко") } })
        XCTAssertEqual(r.map(\.name), ["Мляко demi-écrémé", "Мляко entier"])
    }

    func testRelevantDirectHitsStayFirst() async throws {
        let bg = ["мляко": [p("Мляко прясно")], "lait": [p("Lait entier")]]
        let r = try await FoodSearch.search(query: "мляко", gemini: key, language: .bg,
            plain: { bg[$0] ?? [] }, translate: { _, _, to in to == "French" ? ["lait"] : ["Прясно мляко от крава"] })
        XCTAssertEqual(r.map(\.name), ["Мляко прясно", "Прясно мляко от крава"])
    }

    func testGeminiFailureOnQueryGivesDirectResults() async throws {
        let r = try await search("мляко", tr: { _, _, _ in throw Boom() })
        XCTAssertTrue(r.isEmpty)
    }

    func testFailureTranslatingBackKeepsFrenchNames() async throws {
        var calls = 0
        let r = try await search("мляко", tr: { t, f, to in
            defer { calls += 1 }
            if calls == 0 { return self.fake(t, f, to) }
            throw Boom()
        })
        XCTAssertEqual(r.map(\.name), ["Lait demi-écrémé", "Lait entier"])
    }

    func testFrenchAppLanguageNeverTranslates() async throws {
        let r = try await search("мляко", lang: .fr, tr: { _, _, _ in XCTFail("no"); return [] })
        XCTAssertTrue(r.isEmpty)
    }
}
