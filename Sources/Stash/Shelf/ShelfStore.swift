import Foundation
import UniformTypeIdentifiers

/// The shelf's contents and their persistence in `~/Library/Application Support/Stash/Shelf`:
/// `shelf.json` lists the items (newest first) and `Items/` holds the private copies.
/// It never touches the library folder, and never moves or deletes an original file.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    let folder: URL

    var itemsFolder: URL { folder.appending(path: "Items", directoryHint: .isDirectory) }
    private var manifest: URL { folder.appending(path: "shelf.json") }

    nonisolated static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "Stash/Shelf", directoryHint: .isDirectory)
    }

    init(folder: URL = ShelfStore.defaultFolder) {
        self.folder = folder
        load()
    }

    // MARK: Changes

    /// Puts items on top of the shelf.
    func add(_ new: [ShelfItem]) {
        guard !new.isEmpty else { return }
        items.insert(contentsOf: new, at: 0)
        save()
    }

    /// Takes items off the shelf and deletes their private copies.
    func remove(_ ids: Set<UUID>) {
        let leaving = items.filter { ids.contains($0.id) }
        guard !leaving.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        for item in leaving { deleteCopy(of: item) }
        save()
    }

    func clear() {
        remove(Set(items.map(\.id)))
    }

    /// Whether clearing would lose something that exists only on the shelf.
    var holdsPrivateCopies: Bool { items.contains(where: \.isPrivateCopy) }

    // MARK: Private copies

    /// Writes `data` as a new private copy; returns its name inside `Items/`.
    func storeCopy(_ data: Data, fileExtension: String) throws -> String {
        try FileManager.default.createDirectory(at: itemsFolder, withIntermediateDirectories: true)
        let name = UUID().uuidString + "." + fileExtension
        try data.write(to: itemsFolder.appending(path: name), options: .atomic)
        return name
    }

    /// A new folder inside `Items/` to receive one promised file (so it keeps its original name).
    func makePromiseFolder() throws -> URL {
        let url = itemsFolder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Adds a file that arrived inside a promise folder.
    func addReceivedFile(_ url: URL) {
        let relative = url.deletingLastPathComponent().lastPathComponent + "/" + url.lastPathComponent
        let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
        add([ShelfItem(name: url.lastPathComponent, kind: .stored(fileName: relative, type: isImage ? .image : .file))])
    }

    // MARK: Resolving

    /// The file an item stands for: the original (following moves and renames) or its private
    /// copy. Nil for links, and for originals that are gone or in the Trash.
    func fileURL(for item: ShelfItem) -> URL? {
        switch item.kind {
        case .link:
            return nil
        case .stored(let fileName, _):
            let url = itemsFolder.appending(path: fileName)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        case .file(let bookmark, _, let isDirectory):
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: url.path),
                  !url.path.contains("/.Trash/")
            else { return nil }
            if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
               let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].kind = .file(bookmark: fresh, path: url.path, isDirectory: isDirectory)
                items[index].name = url.lastPathComponent
                save()
            }
            return url
        }
    }

    func isMissing(_ item: ShelfItem) -> Bool {
        if case .link = item.kind { return false }
        return fileURL(for: item) == nil
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: manifest) else {
            cleanUpCopies()
            return
        }
        do {
            items = try Self.decoder.decode([ShelfItem].self, from: data)
            cleanUpCopies()
        } catch {
            // Keep the broken list for inspection, start empty, and leave Items/ alone this time
            // so no private copy is deleted by mistake.
            let aside = folder.appending(path: "shelf.json.broken")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: manifest, to: aside)
            items = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Self.encoder.encode(items).write(to: manifest, options: .atomic)
        } catch {
            NSLog("Stash: couldn't save the shelf: \(error.localizedDescription)")
        }
    }

    /// Deletes anything in `Items/` that no item refers to.
    private func cleanUpCopies() {
        let referenced = Set(items.compactMap { item -> String? in
            guard case .stored(let fileName, _) = item.kind else { return nil }
            return fileName.split(separator: "/").first.map(String.init)
        })
        let contents = (try? FileManager.default.contentsOfDirectory(at: itemsFolder, includingPropertiesForKeys: nil)) ?? []
        for url in contents where !referenced.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func deleteCopy(of item: ShelfItem) {
        guard case .stored(let fileName, _) = item.kind,
              let top = fileName.split(separator: "/").first.map(String.init), !top.isEmpty
        else { return }
        try? FileManager.default.removeItem(at: itemsFolder.appending(path: top))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
