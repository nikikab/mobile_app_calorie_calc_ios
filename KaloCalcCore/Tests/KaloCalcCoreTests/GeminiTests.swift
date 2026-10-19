import XCTest
@testable import KaloCalcCore

final class GeminiTests: XCTestCase {
    func response(_ text: String) -> String {
        let obj: [String: Any] = ["candidates": [["content": ["parts": [["text": text]]]]]]
        return String(data: try! JSONSerialization.data(withJSONObject: obj), encoding: .utf8)!
    }

    func testParsesItemsAndDropsZeroWeight() throws {
        let r = try parseEstimates(response("""
        [{"name":"Пица","grams":300,"kcal":800,"protein_g":30,"carbs_g":90,"fat_g":35},
         {"name":"Нищо","grams":0,"kcal":10,"protein_g":0,"carbs_g":0,"fat_g":0}]
        """))
        XCTAssertEqual(r.count, 1)
        let p = r[0].toProduct()
        XCTAssertEqual(p.kcal100, 266.67, accuracy: 0.01)
        XCTAssertEqual(p.protein100, 10, accuracy: 0.01)
    }

    func testParsesIngredientsAndScalesThem() throws {
        let r = try parseEstimates(response("""
        [{"name":"Салата","grams":300,"kcal":200,"protein_g":5,"carbs_g":20,"fat_g":10,"ingredients":[
          {"name":"Домати","grams":200,"kcal":40,"protein_g":2,"carbs_g":8,"fat_g":0},
          {"name":"Зехтин","grams":10,"kcal":90,"protein_g":0,"carbs_g":0,"fat_g":10},
          {"name":"Нищо","grams":0,"kcal":0,"protein_g":0,"carbs_g":0,"fat_g":0}]}]
        """))
        XCTAssertEqual(r[0].ingredients.count, 2)
        let half = r[0].ingredients[0].scaled(to: 100)
        XCTAssertEqual(half.kcal, 20, accuracy: 0.01)
        XCTAssertEqual(half.proteinG, 1, accuracy: 0.01)
    }

    func testMissingIngredientsIsEmpty() throws {
        XCTAssertEqual(try parseEstimates(response(#"[{"name":"Пица","grams":300,"kcal":800,"protein_g":30,"carbs_g":90,"fat_g":35}]"#))[0].ingredients.count, 0)
    }

    func testEmptyArrayMeansNoFood() throws { XCTAssertEqual(try parseEstimates(response("[]")).count, 0) }

    func testNoCandidatesThrows() {
        XCTAssertThrowsError(try parseEstimates(#"{"candidates":[]}"#)) { XCTAssertEqual($0 as? GeminiError, .noCandidates) }
    }

    func testGarbageTextThrows() {
        XCTAssertThrowsError(try parseEstimates(response("not json"))) { XCTAssertEqual($0 as? GeminiError, .garbled) }
    }

    func testModelNamesKeepOnlyGenerateContent() throws {
        let json = """
        {"models":[
          {"name":"models/gemini-x-flash","supportedGenerationMethods":["generateContent","countTokens"]},
          {"name":"models/embed-1","supportedGenerationMethods":["embedContent"]}]}
        """
        XCTAssertEqual(try parseModelNames(json), ["gemini-x-flash"])
    }

    func testTranslationsReadOneEntryPerInput() {
        XCTAssertEqual(parseTranslations(response(#"["pomme"," lait "]"#), expected: 2), ["pomme", "lait"])
    }

    func testTranslationsRejectWrongCountOrGarbage() {
        XCTAssertNil(parseTranslations(response(#"["pomme"]"#), expected: 2))
        XCTAssertNil(parseTranslations(response("not json"), expected: 1))
    }
}
