import Foundation
import Testing
@testable import Stash

@Suite("Duplicate keys")
struct DuplicateKeyTests {
    private func key(_ string: String) -> String { DuplicateKey.link(URL(string: string)!) }

    @Test func sharingNoiseIsIgnored() {
        #expect(key("https://www.example.com/a/?utm_source=x&b=2&a=1#top") == key("http://example.com/a?a=1&b=2"))
        #expect(key("https://m.example.com/post?fbclid=123") == key("https://example.com/post"))
        #expect(key("https://example.com/post?ref=twitter&si=abc") == key("https://example.com/post"))
    }

    @Test func differentPagesStayDifferent() {
        #expect(key("https://example.com/a") != key("https://example.com/b"))
        #expect(key("https://example.com/a?page=2") != key("https://example.com/a?page=3"))
        #expect(key("https://example.com/A") != key("https://example.com/a"))
        #expect(key("https://example.com/app#/inbox") != key("https://example.com/app#/sent"))
        #expect(key("https://other.com/a") != key("https://example.com/a"))
    }

    @Test func youTubeComparesTheMoment() {
        let short = URL(string: "https://youtu.be/dQw4w9WgXcQ?t=10")!
        let saved = Reference(type: .link, url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=11s"), timestamp: 11)
        #expect(DuplicateKey.link(short, position: 10, matches: saved))
        #expect(!DuplicateKey.link(short, position: 60, matches: saved))

        let start = Reference(type: .link, url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        #expect(DuplicateKey.link(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=x")!, position: nil, matches: start))
        #expect(DuplicateKey.link(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!, position: 0, matches: start))
        #expect(!DuplicateKey.link(URL(string: "https://www.youtube.com/watch?v=aaaaaaaaaaa")!, position: nil, matches: start))
    }

    @Test func textIgnoresSpacingAndCase() {
        #expect(DuplicateKey.text("  Make the viewer\n the HERO ") == DuplicateKey.text("make the viewer the hero"))
        #expect(DuplicateKey.text("Make the viewer the hero") != DuplicateKey.text("Make the brand the hero"))
    }
}

/// A throwaway library, filled through `CaptureSaver` like the app does.
@MainActor
@Suite("Finding and merging duplicates")
final class DuplicateFinderTests {
    let root: URL
    let store: LibraryStore
    let saver: CaptureSaver
    let finder: DuplicateFinder

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashDuplicates-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = try LibraryStore(root: root, index: SearchIndex(path: nil)) { try FileManager.default.removeItem(at: $0) }
        saver = CaptureSaver(library: store)
        finder = DuplicateFinder(library: store)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func save(_ content: CaptureContent, note: String = "") async throws -> Reference {
        try #require(try await saver.save(CaptureItem(content: content, origin: .pasted), note: note))
    }

    private func link(_ string: String, timestamp: Int? = nil) -> CaptureContent {
        .link(URL(string: string)!, title: nil, timestamp: timestamp)
    }

    @Test func nothingInAnEmptyLibrary() async {
        #expect(await finder.existing(for: link("https://example.com")) == nil)
        #expect(await finder.existing(for: .text("hello")) == nil)
        #expect(await finder.existing(for: .image(ClipboardReaderTests.pngData(), fileExtension: "png")) == nil)
    }

    @Test func findsALinkSharedDifferently() async throws {
        let saved = try await save(link("https://growth.design/case-studies/teardown"))
        let found = await finder.existing(for: link("https://www.growth.design/case-studies/teardown/?utm_medium=social"))
        #expect(found?.id == saved.id)
        #expect(await finder.existing(for: link("https://growth.design/case-studies/other")) == nil)
    }

    @Test func aVideoIsTheSameOnlyAtTheSameMoment() async throws {
        let saved = try await save(link("https://www.youtube.com/watch?v=dQw4w9WgXcQ", timestamp: 272))
        #expect(await finder.existing(for: link("https://youtu.be/dQw4w9WgXcQ", timestamp: 273))?.id == saved.id)
        #expect(await finder.existing(for: link("https://youtu.be/dQw4w9WgXcQ", timestamp: 400)) == nil)
    }

    @Test func findsTextIgnoringCase() async throws {
        let saved = try await save(.text("Make the viewer the hero, not the brand."))
        #expect(await finder.existing(for: .text("make the viewer the hero,  not the brand."))?.id == saved.id)
    }

    @Test func findsTheSameImageBytes() async throws {
        let png = ImageTextTests.textImage("SALE")
        let saved = try await save(.image(png, fileExtension: "png"))
        #expect(await finder.existing(for: .image(png, fileExtension: "png"))?.id == saved.id)

        // Same size, other bytes.
        var other = png
        other[other.count - 20] ^= 0xFF
        #expect(await finder.existing(for: .image(other, fileExtension: "png")) == nil)
    }

    @Test func findsTheSameFile() async throws {
        let source = root.appending(path: "brief.txt")
        try Data("Q4 campaign brief".utf8).write(to: source)
        let saved = try await save(.file(source))
        #expect(await finder.existing(for: .file(source))?.id == saved.id)
    }

    @Test func theNewestMatchWins() async throws {
        try await save(.text("Specific beats clever."))
        let newer = try await save(.text("specific beats clever."))
        #expect(await finder.existing(for: .text("Specific beats clever."))?.id == newer.id)
    }

    // MARK: Merging

    @Test func mergingAddsNewTagsAndTheNote() async throws {
        let existing = try await save(link("https://example.com/post"), note: "old #hooks")
        let result = try saver.merge(CaptureItem(content: link("https://example.com/post"), origin: .pasted), note: "new idea #ads #hooks", into: existing)
        guard case .merged(let merged) = result else {
            Issue.record("Expected a merge, got \(result)")
            return
        }
        #expect(merged.tags == ["hooks", "ads"])
        #expect(merged.note == "old\n\nnew idea")
        let reread = try #require(try store.index.reference(id: existing.id))
        #expect(reread.tags == ["hooks", "ads"])
        #expect(try store.index.count() == 1)
    }

    @Test func mergingTheSameNoteTwiceDoesNothing() async throws {
        let existing = try await save(.text("Tension, then release."), note: "from the workshop #copy")
        let before = try String(contentsOf: store.url(for: #require(existing.markdownPath)), encoding: .utf8)
        let result = try saver.merge(nil, note: "from the workshop #copy", into: existing)
        #expect(result == .unchanged(existing))
        #expect(try String(contentsOf: store.url(for: #require(existing.markdownPath)), encoding: .utf8) == before)
    }

    @Test func aLinkWithoutTitleTakesTheNewOne() async throws {
        let existing = try await save(link("https://example.com/post"))
        let item = CaptureItem(content: .link(URL(string: "https://example.com/post")!, title: "The Post", timestamp: nil), origin: .browser("Arc"))
        guard case .merged(let merged) = try saver.merge(item, note: "", into: existing) else {
            Issue.record("Expected a merge")
            return
        }
        #expect(merged.title == "The Post")
    }
}
