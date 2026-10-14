import Foundation

extension Notification.Name {
    /// Posted on the main thread after references were added, changed or removed.
    static let libraryDidChange = Notification.Name("dev.stash.libraryDidChange")
}

/// The library folder: `items/` holds one Markdown file per reference, `assets/` holds images,
/// files and thumbnails named by reference ID. Every write goes to disk first (atomically),
/// then to the search index.
@MainActor
final class LibraryStore {
    enum StoreError: Error {
        case notFound(id: String)
    }

    let root: URL
    let index: SearchIndex
    var itemsURL: URL { root.appending(path: "items", directoryHint: .isDirectory) }
    var assetsURL: URL { root.appending(path: "assets", directoryHint: .isDirectory) }

    /// How removed files leave the library. Defaults to the Trash, so deletes can be undone.
    private let removeFile: (URL) throws -> Void
    private var watcher: FileWatcher?
    private var syncState = SyncState.idle

    private enum SyncState {
        case idle
        case running
        /// Something changed while syncing; run again when done.
        case runningWithPendingRequest
    }

    init(root: URL, index: SearchIndex, removeFile: @escaping (URL) throws -> Void = LibraryStore.moveToTrash) throws {
        self.root = root.standardizedFileURL
        self.index = index
        self.removeFile = removeFile

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: itemsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)

        // The index describes one library folder. If the folder moved, start over.
        if try index.metaValue("root") != self.root.path {
            try index.removeAll()
            try index.setMetaValue(self.root.path, for: "root")
        }
    }

    /// The library at `Preferences.libraryURL`, indexed in `~/Library/Application Support/Stash/`.
    static func openDefault() throws -> LibraryStore {
        let support = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Stash", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let index = try SearchIndex(path: support.appending(path: "index.sqlite").path)
        return try LibraryStore(root: Preferences.libraryURL, index: index)
    }

    nonisolated static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    func url(for relativePath: String) -> URL {
        root.appending(path: relativePath)
    }

    // MARK: Writing

    /// Saves a new reference as `items/YYYY-MM-DD-slug.md` and returns it with its path set.
    @discardableResult
    func create(_ reference: Reference) throws -> Reference {
        var reference = reference
        let filename = Slug.filename(for: reference) { name in
            FileManager.default.fileExists(atPath: itemsURL.appending(path: name).path)
        }
        reference.markdownPath = "items/" + filename
        try write(reference)
        notifyChange()
        return reference
    }

    /// Changes a saved reference. The file keeps its name; its ID can't change.
    @discardableResult
    func update(id: String, _ change: (inout Reference) -> Void) throws -> Reference {
        guard let path = try index.reference(id: id)?.markdownPath else { throw StoreError.notFound(id: id) }
        // Start from the file rather than the index so fields only the file has
        // (front matter added in other editors) survive.
        let markdown = try String(contentsOf: url(for: path), encoding: .utf8)
        var reference = try MarkdownCodec.decode(markdown)
        change(&reference)
        reference.id = id
        reference.markdownPath = path
        try write(reference)
        notifyChange()
        return reference
    }

    /// Removes the reference's file and its assets (to the Trash by default).
    func delete(id: String) throws {
        guard let reference = try index.reference(id: id), let path = reference.markdownPath else {
            throw StoreError.notFound(id: id)
        }
        try removeFile(url(for: path))
        for asset in [reference.file, reference.thumbnail].compactMap({ $0 }) {
            let assetURL = url(for: asset).standardizedFileURL
            let isInAssets = assetURL.path.hasPrefix(assetsURL.standardizedFileURL.path + "/")
            if isInAssets, FileManager.default.fileExists(atPath: assetURL.path) {
                try? removeFile(assetURL)
            }
        }
        try index.remove(id: id)
        notifyChange()
    }

    /// `assets/<id>.<ext>`, relative to the root (no extension if there's none).
    func assetPath(id: String, fileExtension: String) -> String {
        fileExtension.isEmpty ? "assets/\(id)" : "assets/\(id).\(fileExtension.lowercased())"
    }

    /// Writes `data` to `assets/<id>.<ext>` and returns that path, relative to the root.
    func saveAsset(_ data: Data, id: String, fileExtension: String) throws -> String {
        let path = assetPath(id: id, fileExtension: fileExtension)
        try data.write(to: url(for: path), options: .atomic)
        return path
    }

    private func write(_ reference: Reference) throws {
        guard let path = reference.markdownPath else { return }
        let fileURL = url(for: path)
        try Data(MarkdownCodec.encode(reference).utf8).write(to: fileURL, options: .atomic)
        try index.upsert(reference, stamp: LibrarySync.stamp(of: fileURL))
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .libraryDidChange, object: self)
    }

    // MARK: Sync

    /// Watches the folder and re-syncs the index whenever something in it changes.
    func startWatching() {
        watcher = FileWatcher(url: root) { [weak self] in
            MainActor.assumeIsolated { self?.scheduleSync() }
        }
    }

    /// Syncs the index with the folder in the background. Calls made while a sync is
    /// running are folded into one more pass.
    func scheduleSync() {
        switch syncState {
        case .running, .runningWithPendingRequest:
            syncState = .runningWithPendingRequest
            return
        case .idle:
            syncState = .running
        }

        let sync = LibrarySync(root: root, index: index)
        Task.detached(priority: .utility) { [weak self] in
            let result = try? sync.run()
            await self?.syncFinished(changed: result?.hasChanges ?? false)
        }
    }

    private func syncFinished(changed: Bool) {
        if changed { notifyChange() }
        let runAgain = syncState == .runningWithPendingRequest
        syncState = .idle
        if runAgain { scheduleSync() }
    }

    /// Synchronous sync, for tests and the "Rebuild index" setting.
    @discardableResult
    func syncNow() throws -> LibrarySync.Result {
        let result = try LibrarySync(root: root, index: index).run()
        if result.hasChanges { notifyChange() }
        return result
    }
}
