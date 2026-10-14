import Foundation

/// What a reference holds. Stash detects it; the user never picks it.
enum ReferenceType: String, CaseIterable, Sendable {
    case link
    case text
    case image
    case file

    /// Parses the value of a `type:` search filter. Accepts plurals (`type:images`).
    init?(filterValue: String) {
        let value = filterValue.lowercased()
        let singular = value.hasSuffix("s") ? String(value.dropLast()) : value
        self.init(rawValue: singular)
    }
}
