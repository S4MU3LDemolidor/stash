import Foundation

/// Something held on the shelf. Files are held by reference (a bookmark to the original);
/// things with no file of their own are kept as private copies in the shelf's `Items` folder.
struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        /// A file or folder somewhere on disk.
        case file(bookmark: Data, path: String, isDirectory: Bool)
        /// A private copy inside `Items/` (path relative to it): an image, a text or a promised file.
        case stored(fileName: String, type: StoredType)
        case link(URL, title: String?)
    }

    enum StoredType: String, Codable, Sendable {
        case image, text, file
    }

    var id: UUID
    var added: Date
    /// What the shelf shows: a file name, the start of a text, a page title or a host.
    var name: String
    var kind: Kind

    init(id: UUID = UUID(), added: Date = Date(), name: String, kind: Kind) {
        self.id = id
        self.added = added
        self.name = name
        self.kind = kind
    }

    /// A reference to a file or folder on disk.
    static func file(at url: URL) throws -> ShelfItem {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? url.hasDirectoryPath
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return ShelfItem(name: url.lastPathComponent, kind: .file(bookmark: bookmark, path: url.path, isDirectory: isDirectory))
    }

    /// The first line of a text, at most 60 characters (plus an ellipsis).
    static func preview(of text: String) -> String {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.count > 60 ? String(line.prefix(60)) + "\u{2026}" : line
    }

    var isPrivateCopy: Bool {
        if case .stored = kind { return true }
        return false
    }

    /// Shown by file name (files, folders, promised files), as opposed to a text or a title.
    var isFileLike: Bool {
        switch kind {
        case .file, .stored(_, .file): true
        case .stored, .link: false
        }
    }

    var isFolder: Bool {
        if case .file(_, _, let isDirectory) = kind { return isDirectory }
        return false
    }
}
