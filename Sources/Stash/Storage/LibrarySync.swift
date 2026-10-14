import Foundation

/// Brings the index in line with the Markdown files in `items/`: indexes new and changed
/// files and forgets removed ones. Unchanged files (same size and modification date) aren't
/// read again, so this is cheap enough to run on every launch and every folder change.
struct LibrarySync: Sendable {
    let root: URL
    let index: SearchIndex

    struct Result: Equatable {
        var indexed = 0
        var removed = 0
        /// Files that couldn't be read, aren't valid, or duplicate another file's ID.
        var skipped: [String] = []

        var hasChanges: Bool { indexed > 0 || removed > 0 }
    }

    @discardableResult
    func run() throws -> Result {
        let onDisk = markdownFiles()
        let indexed = try index.indexedFiles()

        var result = Result()
        var removedPaths = indexed.keys.filter { onDisk[$0] == nil }

        // Which path owns each ID, so a second file with the same ID (e.g. a sync-conflict
        // copy like "note 2.md") is skipped instead of fighting over the index entry.
        var owners: [String: String] = [:]
        for (path, entry) in indexed where onDisk[path] != nil {
            owners[entry.id] = path
        }

        // Shortest names first: conflict copies get longer names ("a 2.md", "a (conflicted copy).md"),
        // so on a fresh index the original wins.
        let ordered = onDisk.sorted { ($0.key.count, $0.key) < ($1.key.count, $1.key) }

        var upserts: [SearchIndex.Upsert] = []
        for (path, file) in ordered where indexed[path]?.stamp != file.stamp {
            do {
                let markdown = try String(contentsOf: file.url, encoding: .utf8)
                var reference = try MarkdownCodec.decode(markdown, fallbackCreated: file.created)
                reference.markdownPath = path
                if let owner = owners[reference.id], owner != path {
                    result.skipped.append(path)
                    continue
                }
                owners[reference.id] = path
                // New to the index: also read the text inside its attached file (already in the background).
                let fileText = indexed[path] == nil && reference.type == .file
                    ? reference.file.flatMap { FileTextExtractor.text(of: root.appending(path: $0)) }
                    : nil
                upserts.append(SearchIndex.Upsert(reference: reference, stamp: file.stamp, fileText: fileText))
            } catch {
                result.skipped.append(path)
                if indexed[path] != nil { removedPaths.append(path) }
            }
        }

        if !upserts.isEmpty || !removedPaths.isEmpty {
            try index.apply(upserts: upserts, removedPaths: removedPaths)
        }
        result.indexed = upserts.count
        result.removed = removedPaths.count
        return result
    }

    private func markdownFiles() -> [String: (url: URL, stamp: FileStamp, created: Date?)] {
        let items = root.appending(path: "items", directoryHint: .isDirectory)
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: items,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        var files: [String: (url: URL, stamp: FileStamp, created: Date?)] = [:]
        for url in urls where url.pathExtension.lowercased() == "md" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            files["items/" + url.lastPathComponent] = (url, Self.stamp(values), values.creationDate)
        }
        return files
    }

    static func stamp(of url: URL) throws -> FileStamp {
        stamp(try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]))
    }

    private static func stamp(_ values: URLResourceValues) -> FileStamp {
        FileStamp(
            modified: values.contentModificationDate?.timeIntervalSince1970 ?? 0,
            size: Int64(values.fileSize ?? 0)
        )
    }
}
