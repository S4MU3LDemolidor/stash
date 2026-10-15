import Foundation
import Testing
@testable import Stash

/// A throwaway shelf folder and throwaway originals; nothing touches the real shelf.
@MainActor
@Suite("Shelf store")
final class ShelfStoreTests {
    let root: URL
    let shelfFolder: URL
    let originals: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ShelfTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        shelfFolder = root.appending(path: "Shelf", directoryHint: .isDirectory)
        originals = root.appending(path: "Originals", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func original(_ name: String, _ text: String = "hello") throws -> URL {
        let url = originals.appending(path: name)
        try Data(text.utf8).write(to: url)
        return url
    }

    @Test func itemsSurviveAReload() throws {
        let store = ShelfStore(folder: shelfFolder)
        let copy = try store.storeCopy(Data("a note".utf8), fileExtension: "txt")
        store.add([
            ShelfItem(name: "a note", kind: .stored(fileName: copy, type: .text)),
            ShelfItem(name: "example.com", kind: .link(URL(string: "https://example.com")!, title: nil)),
        ])
        let reloaded = ShelfStore(folder: shelfFolder)
        #expect(reloaded.items.count == 2)
        #expect(reloaded.items.map(\.id) == store.items.map(\.id))
        #expect(reloaded.items.map(\.kind) == store.items.map(\.kind))
    }

    @Test func newestFirst() {
        let store = ShelfStore(folder: shelfFolder)
        store.add([ShelfItem(name: "first", kind: .link(URL(string: "https://a.com")!, title: nil))])
        store.add([ShelfItem(name: "second", kind: .link(URL(string: "https://b.com")!, title: nil))])
        #expect(store.items.map(\.name) == ["second", "first"])
    }

    @Test func fileReferencesFollowRenames() throws {
        let url = try original("brief.txt")
        let store = ShelfStore(folder: shelfFolder)
        store.add([try ShelfItem.file(at: url)])
        let renamed = originals.appending(path: "brief-final.txt")
        try FileManager.default.moveItem(at: url, to: renamed)
        #expect(store.fileURL(for: store.items[0])?.lastPathComponent == "brief-final.txt")
        #expect(!store.isMissing(store.items[0]))
    }

    @Test func deletedOriginalsAreMissing() throws {
        let url = try original("gone.txt")
        let store = ShelfStore(folder: shelfFolder)
        store.add([try ShelfItem.file(at: url)])
        try FileManager.default.removeItem(at: url)
        #expect(store.isMissing(store.items[0]))
    }

    @Test func removingDeletesPrivateCopiesButNeverOriginals() throws {
        let url = try original("keep.txt")
        let store = ShelfStore(folder: shelfFolder)
        let copy = try store.storeCopy(Data("only here".utf8), fileExtension: "txt")
        let stored = ShelfItem(name: "only here", kind: .stored(fileName: copy, type: .text))
        let reference = try ShelfItem.file(at: url)
        store.add([stored, reference])
        store.remove([stored.id, reference.id])
        #expect(store.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.itemsFolder.appending(path: copy).path))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func clearingKnowsAboutPrivateCopies() throws {
        let store = ShelfStore(folder: shelfFolder)
        store.add([ShelfItem(name: "link", kind: .link(URL(string: "https://a.com")!, title: nil))])
        #expect(!store.holdsPrivateCopies)
        let copy = try store.storeCopy(Data("x".utf8), fileExtension: "txt")
        store.add([ShelfItem(name: "x", kind: .stored(fileName: copy, type: .text))])
        #expect(store.holdsPrivateCopies)
        store.clear()
        #expect(store.items.isEmpty)
    }

    @Test func strayCopiesAreCleanedUpAtLoad() throws {
        let store = ShelfStore(folder: shelfFolder)
        let kept = try store.storeCopy(Data("kept".utf8), fileExtension: "txt")
        store.add([ShelfItem(name: "kept", kind: .stored(fileName: kept, type: .text))])
        let stray = store.itemsFolder.appending(path: "stray.png")
        try Data("x".utf8).write(to: stray)
        _ = ShelfStore(folder: shelfFolder)
        #expect(!FileManager.default.fileExists(atPath: stray.path))
        #expect(FileManager.default.fileExists(atPath: store.itemsFolder.appending(path: kept).path))
    }

    @Test func aBrokenListIsSetAsideAndCopiesAreKept() throws {
        let store = ShelfStore(folder: shelfFolder)
        let copy = try store.storeCopy(Data("precious".utf8), fileExtension: "txt")
        try Data("{ not json".utf8).write(to: shelfFolder.appending(path: "shelf.json"))
        let reloaded = ShelfStore(folder: shelfFolder)
        #expect(reloaded.items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: shelfFolder.appending(path: "shelf.json.broken").path))
        #expect(FileManager.default.fileExists(atPath: reloaded.itemsFolder.appending(path: copy).path))
    }

    @Test func receivedFilesKeepTheirNames() throws {
        let store = ShelfStore(folder: shelfFolder)
        let folder = try store.makePromiseFolder()
        let file = folder.appending(path: "Invoice.pdf")
        try Data("%PDF".utf8).write(to: file)
        store.addReceivedFile(file)
        #expect(store.items.first?.name == "Invoice.pdf")
        #expect(store.fileURL(for: store.items[0])?.lastPathComponent == "Invoice.pdf")
        store.clear()
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test func textPreviewIsTheFirstLineShortened() {
        #expect(ShelfItem.preview(of: "  Make the viewer the hero\nnot the brand") == "Make the viewer the hero")
        #expect(ShelfItem.preview(of: String(repeating: "a", count: 80)).count == 61)
    }
}
