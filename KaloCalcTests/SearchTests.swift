import XCTest
import UIKit
import KaloCalcCore
@testable import KaloCalc

/// Answers requests from `handler` (by URL) instead of the network.
final class StubTransport: HTTPTransport {
    var handler: (HTTPRequest) -> (Int, String)
    private(set) var requests: [HTTPRequest] = []
    init(_ handler: @escaping (HTTPRequest) -> (Int, String)) { self.handler = handler }
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let (status, body) = handler(request)
        return HTTPResponse(status: status, body: Data(body.utf8))
    }
}

private let offSearch = #"{"hits":[{"product_name":"Мляко","brands":["Верея"],"nutriments":{"energy-kcal_100g":47,"proteins_100g":3.3,"carbohydrates_100g":4.8,"fat_100g":1.5}}]}"#
private let geminiEstimate: String = {
    let inner = #"[{"name":"Ябълка","grams":150,"kcal":78,"protein_g":0.4,"carbs_g":20,"fat_g":0.2,"ingredients":[]}]"#
    let response: [String: Any] = ["candidates": [["content": ["parts": [["text": inner]]]]]]
    return String(decoding: try! JSONSerialization.data(withJSONObject: response), as: UTF8.self)
}()

func testImage(width: CGFloat = 200, height: CGFloat = 100) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { c in
        UIColor.red.setFill()
        c.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

@MainActor
final class FoodSearchViewModelTests: XCTestCase {
    var model: AppModel!

    override func setUp() { model = .inMemory() }

    private func makeVM(_ transport: StubTransport, labels: [FoodLabel] = []) -> FoodSearchViewModel {
        FoodSearchViewModel(model: model, services: FoodServices(transport: transport, recognize: { _ in labels }), language: .en)
    }

    func testSearchShowsResults() async {
        let t = StubTransport { _ in (200, offSearch) }
        let vm = makeVM(t)
        vm.search("мляко")
        await vm.settle()
        XCTAssertEqual(vm.results.map(\.name), ["Мляко"])
        XCTAssertNil(vm.message)
        XCTAssertFalse(vm.loading)
        XCTAssertTrue(t.requests[0].url.absoluteString.hasPrefix("https://search.openfoodfacts.org/search"))
    }

    func testBlankQueryDoesNothing() async {
        let t = StubTransport { _ in (200, offSearch) }
        let vm = makeVM(t)
        vm.search("   ")
        await vm.settle()
        XCTAssertTrue(t.requests.isEmpty)
    }

    func testNoResultsSaysSo() async {
        let vm = makeVM(StubTransport { _ in (200, #"{"hits":[]}"#) })
        vm.search("zzz")
        await vm.settle()
        XCTAssertEqual(vm.message, "No results.")
    }

    func testNetworkFailureBecomesAMessage() async {
        let vm = makeVM(StubTransport { _ in (503, "") })
        vm.search("milk")
        await vm.settle()
        XCTAssertEqual(vm.message, "Error: HTTP 503")
        XCTAssertFalse(vm.loading)
    }

    func testBarcodeFoundAndNotFound() async {
        let found = #"{"status":1,"product":{"product_name":"Хляб","nutriments":{"energy-kcal_100g":250}}}"#
        let vm = makeVM(StubTransport { _ in (200, found) })
        vm.lookupBarcode("123")
        await vm.settle()
        XCTAssertEqual(vm.scanned?.name, "Хляб")
        let missing = makeVM(StubTransport { _ in (200, #"{"status":0}"#) })
        missing.lookupBarcode("999")
        await missing.settle()
        XCTAssertNil(missing.scanned)
        XCTAssertEqual(missing.message, "Barcode 999 was not found.")
    }

    func testPhotoWithoutAKeyOffersLabelsAndAskForTheKey() async throws {
        let t = StubTransport { _ in (500, "") }
        let vm = makeVM(t, labels: [FoodLabel(text: "food", confidence: 0.9), FoodLabel(text: "pizza", confidence: 0.7)])
        vm.photoTaken(testImage())
        await vm.settle()
        XCTAssertEqual(vm.photoLabels, ["pizza"])
        XCTAssertFalse(vm.geminiConfigured)
        XCTAssertTrue(vm.estimates.isEmpty)
        XCTAssertTrue(t.requests.isEmpty)
        let path = try XCTUnwrap(vm.pendingPhoto)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testPhotoWithoutRecognizedFoodSaysSo() async {
        let vm = makeVM(StubTransport { _ in (500, "") }, labels: [])
        vm.photoTaken(testImage())
        await vm.settle()
        XCTAssertEqual(vm.message, "Couldn't recognize a specific food. Try a closer photo or search by hand.")
    }

    func testPhotoWithAKeyGetsGeminiEstimates() async {
        model.settingsStore.saveKey("test-key")
        let t = StubTransport { _ in (200, geminiEstimate) }
        let vm = makeVM(t, labels: [FoodLabel(text: "apple", confidence: 0.8)])
        vm.photoTaken(testImage())
        await vm.settle()
        XCTAssertTrue(vm.geminiConfigured)
        XCTAssertEqual(vm.estimates.map(\.name), ["Ябълка"])
        XCTAssertEqual(t.requests[0].headers["x-goog-api-key"], "test-key")
        XCTAssertNil(vm.message)
    }

    func testGeminiFailureKeepsTheLabelsAndShowsTheError() async {
        model.settingsStore.saveKey("test-key")
        let vm = makeVM(StubTransport { _ in (429, "") }, labels: [FoodLabel(text: "apple", confidence: 0.8)])
        vm.photoTaken(testImage())
        await vm.settle()
        XCTAssertEqual(vm.photoLabels, ["apple"])
        XCTAssertTrue(vm.estimates.isEmpty)
        XCTAssertEqual(vm.message, "Error: Gemini's free limit is used up. Try again later.")
    }

    func testResetForgetsTheSearchButKeepsFavorites() async throws {
        try model.repository.saveFavorite(Favorite(name: "Egg", grams: 60, kcal: 90, proteinG: 7, carbsG: 0, fatG: 6))
        let vm = makeVM(StubTransport { _ in (200, offSearch) })
        vm.search("x")
        await vm.settle()
        vm.reset()
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertNil(vm.pendingPhoto)
        vm.reloadFavorites()
        XCTAssertEqual(vm.favorites.map(\.name), ["Egg"])
    }

    func testFavoritesCanBeSavedFromAnEstimateAndRemoved() {
        let vm = makeVM(StubTransport { _ in (500, "") })
        vm.saveFavorite(FoodEstimate(name: " Soup ", grams: 300, kcal: 150.4, proteinG: 5, carbsG: 20, fatG: 4))
        XCTAssertEqual(vm.favorites.map(\.name), ["Soup"])
        XCTAssertEqual(vm.favorites[0].kcal, 150)
        vm.saveFavorite(FoodEstimate(name: "", grams: 300, kcal: 1, proteinG: 0, carbsG: 0, fatG: 0))
        XCTAssertEqual(vm.favorites.count, 1)
        vm.removeFavorite(vm.favorites[0])
        XCTAssertTrue(vm.favorites.isEmpty)
    }

    func testFavoritePhotosMapTheNewestPhotoToTheFoodName() throws {
        try model.repository.insert(FoodEntry(epochDay: 1, meal: .lunch, name: "Soup", kcal: 1, photoPath: "old.jpg"))
        try model.repository.insert(FoodEntry(epochDay: 2, meal: .lunch, name: "Soup", kcal: 1, photoPath: "new.jpg"))
        let vm = makeVM(StubTransport { _ in (500, "") })
        XCTAssertEqual(vm.favoritePhotos, ["Soup": "new.jpg"])
    }

    func testIngredientSearchGoesToOpenFoodFacts() async throws {
        let t = StubTransport { _ in (200, offSearch) }
        let r = try await makeVM(t).searchIngredients(" rice ")
        XCTAssertEqual(r.count, 1)
        XCTAssertTrue(t.requests[0].url.absoluteString.contains("q=rice&"))
    }
}

final class PhotoStoreTests: XCTestCase {
    func testImportDownsizesToTheLongerSide() throws {
        let store = PhotoStore.temporary()
        let url = try store.importPending(testImage(width: 3000, height: 2000))
        let stored = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        XCTAssertEqual(stored.size, CGSize(width: 1280, height: 853))
    }

    func testSmallPhotosAreNotEnlarged() throws {
        let url = try PhotoStore.temporary().importPending(testImage(width: 300, height: 200))
        XCTAssertEqual(try XCTUnwrap(UIImage(contentsOfFile: url.path)).size, CGSize(width: 300, height: 200))
    }

    func testUnreadableDataIsRejected() {
        XCTAssertThrowsError(try PhotoStore.temporary().importPending(data: Data([1, 2, 3])))
    }

    func testCommitMovesThePendingPhotoIntoPermanentStorage() throws {
        let store = PhotoStore.temporary()
        let pending = try store.importPending(testImage())
        let name = try XCTUnwrap(try store.commitPending(pending.path))
        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: name).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
    }

    func testKeepPendingLeavesTheSourceForTheNextCopy() throws {
        let store = PhotoStore.temporary()
        let pending = try store.importPending(testImage())
        let a = try XCTUnwrap(try store.commitPending(pending.path, keepPending: true))
        let b = try XCTUnwrap(try store.commitPending(pending.path, keepPending: true))
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.path))
        store.discardPending(pending.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
    }

    func testCommitWithoutAPendingPhotoGivesNil() throws {
        let store = PhotoStore.temporary()
        XCTAssertNil(try store.commitPending(nil))
        XCTAssertNil(try store.commitPending("/nonexistent/photo.jpg"))
    }

    func testDeleteAndLoad() throws {
        let store = PhotoStore.temporary()
        let name = try XCTUnwrap(try store.commitPending(try store.importPending(testImage(width: 800, height: 400)).path))
        let thumb = try XCTUnwrap(store.load(name, maxPixel: 100))
        XCTAssertLessThanOrEqual(max(thumb.size.width * thumb.scale, thumb.size.height * thumb.scale), 100)
        store.delete(name)
        XCTAssertNil(store.load(name, maxPixel: 100))
    }
}

@MainActor
final class DiaryPhotoTests: XCTestCase {
    func testEntryKeepsThePhotoAndDeletingTheEntryRemovesIt() throws {
        let model = AppModel.inMemory()
        let vm = DiaryViewModel(model: model)
        let pending = try model.photos.importPending(testImage())
        vm.add(EntryValues(meal: .lunch, name: "Soup", grams: 0, kcal: 100, proteinG: 0, carbsG: 0, fatG: 0), pendingPhoto: pending.path)
        let name = try XCTUnwrap(vm.entries[0].photoPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: model.photos.url(for: name).path))
        vm.delete(vm.entries[0])
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.photos.url(for: name).path))
    }

    func testAddAllGivesEachEntryItsOwnCopyOfThePhoto() throws {
        let model = AppModel.inMemory()
        let vm = DiaryViewModel(model: model)
        let pending = try model.photos.importPending(testImage())
        let items = [FoodEstimate(name: "A", grams: 100, kcal: 50.5, proteinG: 1, carbsG: 2, fatG: 3),
                     FoodEstimate(name: "B", grams: 200, kcal: 80, proteinG: 1, carbsG: 2, fatG: 3)]
        vm.addAll(meal: .dinner, items: items, pendingPhoto: pending.path)
        XCTAssertEqual(vm.entries.map(\.name), ["A", "B"])
        XCTAssertEqual(vm.entries.map(\.kcal), [51, 80])
        let names = vm.entries.compactMap(\.photoPath)
        XCTAssertEqual(Set(names).count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
        vm.delete(vm.entries[0])
        XCTAssertTrue(FileManager.default.fileExists(atPath: model.photos.url(for: names[1]).path))
    }

    func testEntryWithoutAPhotoStaysWithout() {
        let vm = DiaryViewModel(model: .inMemory())
        vm.add(EntryValues(meal: .snack, name: "Tea", grams: 0, kcal: 1, proteinG: 0, carbsG: 0, fatG: 0))
        XCTAssertNil(vm.entries[0].photoPath)
    }
}
