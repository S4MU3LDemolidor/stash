import Foundation

/// What the user typed in Library search, split into free-text terms and filters:
/// `hooks #thumbnails type:image` → terms `["hooks"]`, tags `["thumbnails"]`, types `[.image]`.
struct SearchQuery: Equatable, Sendable {
    var terms: [String] = []
    var tags: [String] = []
    var types: [ReferenceType] = []

    static func parse(_ text: String) -> SearchQuery {
        var query = SearchQuery()
        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            if word.hasPrefix("#") {
                // A lone or invalid `#…` is a tag still being typed: not a term either.
                if let tag = TagParser.normalize(word), !query.tags.contains(tag) {
                    query.tags.append(tag)
                }
                continue
            }
            if word.lowercased().hasPrefix("type:") {
                let value = String(word.dropFirst("type:".count))
                if value.isEmpty { continue }
                if let type = ReferenceType(filterValue: value) {
                    if !query.types.contains(type) { query.types.append(type) }
                    continue
                }
            }
            query.terms.append(word)
        }
        return query
    }

    var isEmpty: Bool { terms.isEmpty && tags.isEmpty && types.isEmpty }

    /// FTS5 MATCH expression: every term must match, each as a prefix so results update on
    /// every keystroke. Nil when no term has anything searchable in it.
    var ftsPattern: String? {
        let parts = terms.compactMap { term -> String? in
            guard term.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
            return "\"" + term.replacingOccurrences(of: "\"", with: "\"\"") + "\"*"
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
