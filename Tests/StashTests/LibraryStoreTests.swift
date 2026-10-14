import Foundation
import Testing
@testable import Stash

/// Runs against a throwaway library folder; files are deleted for real instead of trashed.
@MainActor
@Suite("Library store and sync")
final class LibraryStoreTests {
    let root: URL
    let index: SearchIndex
    let store: LibraryStore

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        index = try SearchIndex(path: nil)
        store = try LibraryStore(root: root, index: index) { try FileManager.default.removeItem(at: $0) }
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func sample(note: String = "great hook in the first 3s") -> Reference {
        Reference(
            type: .link,
            created: MarkdownCodec.parseDate("2026-10-14T15:00:00Z")!,
            url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
            title: "How I Write Hooks That Stop the Scroll",
            site: "youtube.com",
            timestamp: 272,
            tags: ["hooks"],
            note: note
        )
    }

    private func read(_ path: String) throws -> String {
        try String(contentsOf: store.url(for: path), encoding: .utf8)
    }

    private func write(_ text: String, to name: String) throws {
        try text.write(to: store.itemsURL.appending(path: name), atomically: true, encoding: .utf8)
    }

    // MARK: Create, update, delete

    @Test func createsTheFoldersAndAFilePerReference() throws {
        let saved = try store.create(sample())
        let path = try #require(saved.markdownPath)

        #expect(FileManager.default.fileExists(atPath: store.assetsURL.path))
        #expect(path.hasPrefix("items/2026-10-1"))
        #expect(path.hasSuffix("-great-hook-in-the-first-3s.md"))
        var decoded = try MarkdownCodec.decode(read(path))
        decoded.markdownPath = path
        #expect(decoded == saved)
        #expect(try index.reference(id: saved.id) == saved)
    }

    @Test func sameSlugGetsANumberedName() throws {
        let first = try store.create(sample())
        let second = try store.create(sample())
        #expect(second.markdownPath == first.markdownPath?.replacingOccurrences(of: ".md", with: "-2.md"))
    }

    @Test func updateRewritesTheFileInPlaceAndKeepsUnknownFields() throws {
        let saved = try store.create(sample())
        let path = try #require(saved.markdownPath)
        // Someone adds a field in another editor.
        try read(path).replacingOccurrences(of: "created:", with: "rating: 5\ncreated:")
            .write(to: store.url(for: path), atomically: true, encoding: .utf8)

        let updated = try store.update(id: saved.id) { reference in
            reference.note = "edited"
            reference.tags = ["hooks", "edits"]
        }

        #expect(updated.markdownPath == path)
        let markdown = try read(path)
        #expect(markdown.contains("rating: 5"))
        #expect(markdown.contains("tags: [hooks, edits]"))
        #expect(markdown.hasSuffix("---\nedited\n"))
        #expect(try index.search(SearchQuery.parse("#edits")).map(\.id) == [saved.id])
    }

    @Test func deleteRemovesTheFileItsAssetsAndTheIndexEntry() throws {
        var reference = sample()
        reference.thumbnail = try store.saveAsset(Data([1, 2, 3]), id: reference.id, fileExtension: "JPG")
        let saved = try store.create(reference)
        #expect(saved.thumbnail == "assets/\(saved.id).jpg")

        try store.delete(id: saved.id)

        #expect(!FileManager.default.fileExists(atPath: store.url(for: saved.markdownPath!).path))
        #expect(!FileManager.default.fileExists(atPath: store.url(for: saved.thumbnail!).path))
        #expect(try index.count() == 0)
    }

    @Test func unknownIDsThrow() {
        #expect(throws: LibraryStore.StoreError.self) { try self.store.delete(id: "nope") }
        #expect(throws: LibraryStore.StoreError.self) { try self.store.update(id: "nope") { _ in } }
    }

    // MARK: Sync with changes made outside Stash

    @Test func syncPicksUpNewEditedAndRemovedFiles() throws {
        try write("---\nid: A\ntype: text\ntags: [ideas]\ncreated: 2026-10-14T10:00:00Z\n---\nFirst idea\n", to: "a.md")
        try write("---\nid: B\ntype: text\ncreated: 2026-10-14T11:00:00Z\n---\nSecond idea\n", to: "b.md")
        #expect(try store.syncNow() == LibrarySync.Result(indexed: 2, removed: 0))

        // Nothing changed: nothing is re-read.
        #expect(try store.syncNow() == LibrarySync.Result())

        try write("---\nid: A\ntype: text\ntags: [ideas]\ncreated: 2026-10-14T10:00:00Z\n---\nRewritten idea\n", to: "a.md")
        try FileManager.default.removeItem(at: store.itemsURL.appending(path: "b.md"))
        #expect(try store.syncNow() == LibrarySync.Result(indexed: 1, removed: 1))

        #expect(try index.search(SearchQuery.parse("rewritten")).map(\.id) == ["A"])
        #expect(try index.count() == 1)
    }

    @Test func syncSkipsInvalidFilesAndDuplicateIDs() throws {
        try write("---\nid: A\ntype: text\ncreated: 2026-10-14T10:00:00Z\n---\nOriginal\n", to: "a.md")
        try write("---\nid: A\ntype: text\ncreated: 2026-10-14T10:00:00Z\n---\nConflict copy\n", to: "a 2.md")
        try write("No front matter here", to: "readme.md")
        try write("---\nid: C\n---\nnot markdown", to: "notes.txt")

        let result = try store.syncNow()
        #expect(result.indexed == 1)
        #expect(result.skipped.sorted() == ["items/a 2.md", "items/readme.md"])
        #expect(try index.reference(id: "A")?.markdownPath == "items/a.md")

        // Still stable on the next pass.
        try store.syncNow()
        #expect(try index.reference(id: "A")?.markdownPath == "items/a.md")
    }

    @Test func aFileThatBecomesInvalidLeavesTheIndex() throws {
        try write("---\nid: A\ntype: text\ncreated: 2026-10-14T10:00:00Z\n---\nIdea\n", to: "a.md")
        try store.syncNow()
        try write("broken now", to: "a.md")

        try store.syncNow()
        #expect(try index.count() == 0)
    }

    @Test func movingTheLibraryResetsTheIndex() throws {
        try store.create(sample())
        let otherRoot = root.appending(path: "elsewhere", directoryHint: .isDirectory)
        _ = try LibraryStore(root: otherRoot, index: index) { try FileManager.default.removeItem(at: $0) }
        #expect(try index.count() == 0)
    }
}
