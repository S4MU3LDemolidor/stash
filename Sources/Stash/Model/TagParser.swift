import Foundation

/// Inline `#tags` in a note: `great hook in the first 3s #hooks #thumbnails`.
///
/// Rules (compatible with Obsidian): a tag starts with `#` at the start of the text or after
/// whitespace, continues with letters, numbers, `_`, `-` or `/`, and needs at least one
/// character that isn't a digit (`#2024` is not a tag). Tags are lowercased.
enum TagParser {
    struct Result: Equatable {
        /// The note with its tags removed and whitespace tidied.
        var text: String
        /// Tags in order of appearance, without duplicates.
        var tags: [String]
    }

    static func parse(_ input: String) -> Result {
        var tags: [String] = []
        var kept: [Substring] = []

        for word in input.split(separator: " ", omittingEmptySubsequences: true) {
            if let (tag, rest) = splitTag(word) {
                if !tags.contains(tag) { tags.append(tag) }
                // Keep trailing punctuation that isn't part of the tag ("#hooks," → ",").
                if !rest.isEmpty { kept.append(rest) }
            } else {
                kept.append(word)
            }
        }

        let text = kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(text: text, tags: tags)
    }

    /// Validates and normalizes a tag that comes from elsewhere (front matter, filters).
    /// Accepts it with or without the leading `#`.
    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let body = trimmed.hasPrefix("#") ? trimmed.dropFirst() : Substring(trimmed)
        guard !body.isEmpty, body.allSatisfy(isTagCharacter), body.contains(where: { !$0.isNumber }) else {
            return nil
        }
        return body.lowercased()
    }

    /// The text that's currently being typed as a tag at the end of `input`, if any
    /// (`"note #ho"` → `"ho"`). Used for tag autocomplete.
    static func partialTag(atEndOf input: String) -> String? {
        guard let last = input.split(separator: " ", omittingEmptySubsequences: false).last,
              last.hasPrefix("#") else { return nil }
        let body = last.dropFirst()
        return body.allSatisfy(isTagCharacter) ? body.lowercased() : nil
    }

    /// `#hooks,` → ("hooks", ","). Nil if the word doesn't start with a valid tag.
    private static func splitTag(_ word: Substring) -> (String, Substring)? {
        guard word.hasPrefix("#") else { return nil }
        let body = word.dropFirst()
        let end = body.firstIndex { !isTagCharacter($0) } ?? body.endIndex
        let tagBody = body[body.startIndex..<end]
        guard let tag = normalize(String(tagBody)) else { return nil }
        return (tag, body[end...])
    }

    private static func isTagCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-" || character == "/"
    }
}
