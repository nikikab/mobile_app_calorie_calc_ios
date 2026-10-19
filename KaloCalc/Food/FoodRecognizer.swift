import Foundation
import Vision
import KaloCalcCore

/// On-device image classification: free, offline, no API key. Labels are generic English terms, not exact dishes.
enum FoodRecognizer {
    static func labels(in imageURL: URL) async -> [FoodLabel] {
        await Task.detached(priority: .userInitiated) { () -> [FoodLabel] in
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(url: imageURL)
            // A device that can't classify (the simulator, for one) just offers no suggestions.
            guard (try? handler.perform([request])) != nil else { return [] }
            return (request.results ?? []).filter { $0.confidence >= 0.3 }.map { FoodLabel(text: $0.identifier, confidence: $0.confidence) }
        }.value
    }
}
