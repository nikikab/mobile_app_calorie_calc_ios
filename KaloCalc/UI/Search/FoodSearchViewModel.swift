import UIKit
import Observation
import KaloCalcCore

@MainActor
@Observable
final class FoodSearchViewModel {
    private let model: AppModel
    private let services: FoodServices
    private let language: AppLanguage
    private var task: Task<Void, Never>?

    private(set) var results: [Product] = []
    private(set) var loading = false
    var message: String?
    /// Set when a barcode lookup found a product to pick a portion for.
    var scanned: Product?
    /// Suggested search terms from the last photo; empty until a photo is recognized.
    private(set) var photoLabels: [String] = []
    /// Path of the downsized photo waiting to be attached to the next saved entry.
    private(set) var pendingPhoto: String?
    /// Gemini's guesses for the pending photo; empty without a key or while still loading.
    private(set) var estimates: [FoodEstimate] = []
    private(set) var geminiConfigured = false
    /// Set when a photo is ready to be sent to Gemini but the user has not agreed to that yet.
    var awaitingConsent = false
    private var consentPhoto: URL?
    private(set) var favorites: [Favorite] = []
    /// Latest diary photo for each food name, shown next to the favorite with that name.
    private(set) var favoritePhotos: [String: String] = [:]

    init(model: AppModel, services: FoodServices = .live, language: AppLanguage = .current) {
        self.model = model
        self.services = services
        self.language = language
        reloadFavorites()
    }

    func reloadFavorites() {
        favorites = (try? model.repository.favorites()) ?? []
        let withPhoto = (try? model.repository.entriesWithPhoto()) ?? []
        favoritePhotos = Dictionary(withPhoto.compactMap { e in e.photoPath.map { (e.name, $0) } }, uniquingKeysWith: { _, newest in newest })
    }

    func saveFavorite(_ e: FoodEstimate) {
        let f = e.toFavorite()
        guard !f.name.isEmpty, f.grams > 0 else { return }
        try? model.repository.saveFavorite(f)
        reloadFavorites()
    }

    func removeFavorite(_ f: Favorite) {
        try? model.repository.deleteFavorite(id: f.id)
        reloadFavorites()
    }

    func search(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        run { [self] in
            // Without the user's agreement the key is left out, so nothing is translated or sent to Gemini.
            let gemini = model.settingsStore.geminiForSending
            let off = OpenFoodFactsClient(services.transport)
            let client = GeminiClient(services.transport)
            let found = try await FoodSearch.search(query: q, gemini: gemini, language: language, plain: off.search) { texts, from, to in
                try await client.translate(apiKey: gemini.apiKey, model: gemini.model, texts: texts, from: from, to: to)
            }
            results = found
            message = found.isEmpty ? tr("search_none") : nil
        }
    }

    func lookupBarcode(_ code: String) {
        run { [self] in
            let p = try await OpenFoodFactsClient(services.transport).byBarcode(code)
            scanned = p
            message = p == nil ? tr("search_barcode_not_found", code) : nil
        }
    }

    func photoTaken(_ image: UIImage) {
        run { [self] in try await handlePhoto(model.photos.importPending(image)) }
    }

    func photoPicked(_ data: Data) {
        run { [self] in try await handlePhoto(model.photos.importPending(data: data)) }
    }

    private func handlePhoto(_ file: URL) async throws {
        let labels = specificFoodLabels(await services.recognize(file)).map(\.text)
        pendingPhoto = file.path
        photoLabels = labels
        estimates = []
        results = []
        message = labels.isEmpty ? tr("search_no_food_recognized") : nil
        // Labels show immediately; the slower, online Gemini estimate arrives after them.
        let gemini = model.settingsStore.gemini
        geminiConfigured = gemini.enabled
        guard gemini.enabled else { return }
        guard model.settingsStore.geminiConsent else {
            consentPhoto = file
            awaitingConsent = true
            return
        }
        try await estimate(file, gemini)
    }

    private func estimate(_ file: URL, _ gemini: GeminiSettings) async throws {
        let found = try await GeminiClient(services.transport).estimate(
            apiKey: gemini.apiKey, model: gemini.model, jpeg: Data(contentsOf: file), language: language.englishName)
        estimates = found
        message = found.isEmpty ? tr("search_gemini_no_food") : nil
    }

    /// The user agreed: remember it and send the photo that was waiting.
    func grantConsent() {
        model.settingsStore.saveGeminiConsent(true)
        awaitingConsent = false
        guard let file = consentPhoto else { return }
        consentPhoto = nil
        run { [self] in try await estimate(file, model.settingsStore.gemini) }
    }

    /// The user said not now: the photo stays with its on-device suggestions and nothing is sent.
    func declineConsent() {
        awaitingConsent = false
        consentPhoto = nil
    }

    /// Shows a dish as the user corrected it, in place of the recognized one.
    func replaceEstimate(_ original: FoodEstimate, with changed: FoodEstimate) {
        estimates = estimates.map { $0 == original ? changed : $0 }
    }

    func clearPhoto() {
        awaitingConsent = false; consentPhoto = nil
        pendingPhoto = nil; photoLabels = []; estimates = []; message = nil
    }

    /// Forgets the last search, so the screen opens empty next time. Favorites and photos of past entries are kept.
    func reset() {
        task?.cancel()
        model.photos.discardPending(pendingPhoto)
        results = []; loading = false; message = nil; scanned = nil
        awaitingConsent = false; consentPhoto = nil
        pendingPhoto = nil; photoLabels = []; estimates = []
    }

    /// Searches Open Food Facts for an ingredient to add to a dish.
    func searchIngredients(_ query: String) async throws -> [Product] {
        try await OpenFoodFactsClient(services.transport).search(query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Runs `block` as the current operation, replacing any earlier one; failures become the message.
    private func run(_ block: @escaping () async throws -> Void) {
        task?.cancel()
        loading = true
        message = nil
        task = Task { [weak self] in
            do {
                try await block()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.message = tr("error_prefix", userMessage(for: error))
            }
            self?.loading = false
        }
    }

    /// Fills the screen with sample results for screenshots (`-demo` launch argument); nothing is looked up.
    func loadDemo(_ kind: String) {
        switch kind {
        case "search":
            results = [
                Product(name: "Whole milk", brand: "Valio", kcal100: 64, protein100: 3.4, carbs100: 4.7, fat100: 3.6),
                Product(name: "Semi-skimmed milk", brand: "Alpro", kcal100: 46, protein100: 3.4, carbs100: 4.8, fat100: 1.6),
                Product(name: "Milk chocolate", brand: "Milka", kcal100: 535, protein100: 6.3, carbs100: 58, fat100: 30),
            ]
        case "photo", "edit":
            let size = CGSize(width: 600, height: 600)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { c in
                UIColor(red: 0.93, green: 0.78, blue: 0.55, alpha: 1).setFill()
                c.fill(CGRect(origin: .zero, size: size))
                UIColor.white.setFill()
                c.cgContext.fillEllipse(in: CGRect(x: 80, y: 80, width: 440, height: 440))
                UIColor(red: 0.45, green: 0.62, blue: 0.3, alpha: 1).setFill()
                c.cgContext.fillEllipse(in: CGRect(x: 170, y: 170, width: 260, height: 260))
            }
            pendingPhoto = (try? model.photos.importPending(image))?.path
            photoLabels = ["salad", "chicken"]
            geminiConfigured = true
            estimates = [
                FoodEstimate(name: "Chicken salad", grams: 320, kcal: 420, proteinG: 38, carbsG: 14, fatG: 22, ingredients: [
                    Ingredient(name: "Chicken breast", grams: 120, kcal: 198, proteinG: 37, carbsG: 0, fatG: 4),
                    Ingredient(name: "Mixed greens", grams: 150, kcal: 30, proteinG: 2, carbsG: 6, fatG: 0),
                    Ingredient(name: "Olive oil dressing", grams: 50, kcal: 192, proteinG: 0, carbsG: 8, fatG: 18),
                ]),
                FoodEstimate(name: "Whole-grain bread", grams: 60, kcal: 150, proteinG: 6, carbsG: 28, fatG: 2,
                             ingredients: [Ingredient(name: "Whole-grain bread", grams: 60, kcal: 150, proteinG: 6, carbsG: 28, fatG: 2)]),
            ]
        default:
            break
        }
    }

    /// Waits for the current operation, for tests.
    func settle() async { await task?.value }
}
