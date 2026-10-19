import Foundation

/// Food search with a French fallback: most Open Food Facts entries are French, so when a search finds nothing
/// (or only a few results that don't even contain the query words) and a Gemini key is set, the query is
/// translated to French, searched again, and the product names are translated back to the app language.
/// Without a key, or if Gemini fails, it behaves like a plain search.
public enum FoodSearch {
    private static let french = AppLanguage.fr.englishName
    private static let enoughMatches = 3

    /// Whether `name` contains every word of `query`, ignoring case.
    public static func matches(_ name: String, _ query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let n = name.lowercased()
        return !words.isEmpty && words.allSatisfy { n.range(of: $0) != nil }
    }

    public static func search(
        query: String, gemini: GeminiSettings, language: AppLanguage,
        plain: (String) async throws -> [Product],
        /// Translates a list of texts from the first language to the second (English names).
        translate: ([String], String, String) async throws -> [String]
    ) async throws -> [Product] {
        let direct = try await plain(query)
        let relevant = direct.filter { matches($0.name, query) }
        if relevant.count >= enoughMatches || !gemini.enabled || language == .fr { return direct }
        let frenchQuery: String
        do {
            frenchQuery = try await translate([query], language.englishName, french).first ?? ""
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return direct
        }
        if frenchQuery.trimmingCharacters(in: .whitespaces).isEmpty || frenchQuery.caseInsensitiveCompare(query) == .orderedSame {
            return direct
        }
        let found = try await plain(frenchQuery)
        if found.isEmpty { return direct }
        var names = found.map(\.name) // untranslated French results beat none
        do {
            names = try await translate(found.map(\.name), french, language.englishName)
        } catch is CancellationError {
            throw CancellationError()
        } catch {}
        let translated = zip(found, names).map { p, n -> Product in
            var q = p
            if !n.trimmingCharacters(in: .whitespaces).isEmpty { q.name = n }
            return q
        }
        // Direct hits that match the query stay first; the rest were random, so the French results replace them.
        var seen = Set<String>()
        return (relevant + translated).filter { seen.insert($0.name.lowercased() + "\u{0}" + $0.brand.lowercased()).inserted }
    }
}
