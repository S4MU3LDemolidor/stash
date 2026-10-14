import Foundation

/// File names for references: `YYYY-MM-DD-slug.md`.
enum Slug {
    static let maxLength = 50

    /// `"Ação: How I Write Hooks!"` → `"acao-how-i-write-hooks"`. Accents are folded,
    /// anything that isn't a letter or number becomes a single `-`, and the result is cut
    /// to `maxLength` characters, preferably at a word boundary.
    static func make(_ text: String, maxLength: Int = Slug.maxLength) -> String {
        let folded = text
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        var slug = ""
        for character in folded {
            if character.isLetter || character.isNumber {
                slug.append(character)
            } else if !slug.isEmpty, slug.last != "-" {
                slug.append("-")
            }
        }
        slug = trimDashes(slug)

        guard slug.count > maxLength else { return slug }
        let cut = String(slug.prefix(maxLength))
        let nextIsBoundary = slug[slug.index(slug.startIndex, offsetBy: maxLength)] == "-"
        if !nextIsBoundary, let lastDash = cut.lastIndex(of: "-"), cut.distance(from: cut.startIndex, to: lastDash) >= maxLength / 2 {
            return trimDashes(String(cut[..<lastDash]))
        }
        return trimDashes(cut)
    }

    /// The Markdown file name for `reference`, adding `-2`, `-3`… when `isTaken` says the
    /// name is already used.
    static func filename(
        for reference: Reference,
        calendar: Calendar = .current,
        isTaken: (String) -> Bool
    ) -> String {
        let date = reference.created.formatted(
            Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        )
        let slug = make(reference.slugSource)
        let base = slug.isEmpty ? "\(date)-\(reference.type.rawValue)" : "\(date)-\(slug)"

        var candidate = "\(base).md"
        var counter = 2
        while isTaken(candidate) {
            candidate = "\(base)-\(counter).md"
            counter += 1
        }
        return candidate
    }

    private static func trimDashes(_ string: String) -> String {
        string.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
