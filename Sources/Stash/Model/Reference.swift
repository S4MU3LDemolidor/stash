import Foundation

/// One saved reference: the YAML front matter and body of a Markdown file in `items/`
/// (what-the-app-is.md, "Where data lives").
///
/// The body holds the note, except for text references, where the body is the saved text
/// and the note lives in a `note:` front-matter field.
struct Reference: Identifiable, Equatable, Sendable {
    /// ULID.
    var id: String
    var type: ReferenceType
    var created: Date

    var url: URL?
    var title: String?
    /// Host without `www.`, e.g. `youtube.com`.
    var site: String?
    /// YouTube playback position, in seconds.
    var timestamp: Int?
    /// Image or attached file inside the library, relative to its root (`assets/ID.png`).
    var file: String?
    /// The original name of a dropped file (`filename:` in the front matter).
    var originalFilename: String?
    var width: Int?
    var height: Int?
    /// Thumbnail inside the library, relative to its root (`assets/ID.jpg`).
    var thumbnail: String?
    /// Lowercased, without `#`.
    var tags: [String]
    /// The user's note, with its `#tags` already parsed out into `tags`.
    var note: String
    /// The saved text itself. Text references only.
    var text: String?

    /// Front-matter entries Stash doesn't know (e.g. added in Obsidian), kept verbatim
    /// so that saving a reference never drops them.
    var extraFields: [FrontMatterEntry] = []

    /// Location of the Markdown file relative to the library root (`items/…md`).
    /// Not stored in the file itself; nil until the reference is saved.
    var markdownPath: String?

    init(
        id: String = ULID.generate(),
        type: ReferenceType,
        created: Date = Reference.now(),
        url: URL? = nil,
        title: String? = nil,
        site: String? = nil,
        timestamp: Int? = nil,
        file: String? = nil,
        originalFilename: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        thumbnail: String? = nil,
        tags: [String] = [],
        note: String = "",
        text: String? = nil
    ) {
        self.id = id
        self.type = type
        self.created = created
        self.url = url
        self.title = title
        self.site = site
        self.timestamp = timestamp
        self.file = file
        self.originalFilename = originalFilename
        self.width = width
        self.height = height
        self.thumbnail = thumbnail
        self.tags = tags
        self.note = note
        self.text = text
    }

    /// The current time rounded down to whole seconds, which is what the file can store.
    static func now() -> Date {
        Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
    }

    /// `www.youtube.com` → `youtube.com`.
    static func site(for url: URL) -> String? {
        guard var host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else { return nil }
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        return host
    }

    /// The text a filename slug is made from: the note, else the title, the text,
    /// the original file name, the site, and finally the type.
    var slugSource: String {
        let candidates: [String?] = [
            note,
            title,
            text?.split(whereSeparator: \.isNewline).first.map(String.init),
            originalFilename.map { ($0 as NSString).deletingPathExtension },
            site,
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? type.rawValue
    }
}

/// One raw `key: value` entry of the YAML front matter (possibly spanning several lines).
struct FrontMatterEntry: Equatable, Sendable {
    var key: String
    /// The entry exactly as it appeared in the file, including the key and any continuation lines.
    var raw: String
}
