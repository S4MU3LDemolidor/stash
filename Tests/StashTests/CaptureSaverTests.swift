import Foundation
import Testing
@testable import Stash

@MainActor
@Suite("Saving captures")
final class CaptureSaverTests {
    let root: URL
    let store: LibraryStore
    let saver: CaptureSaver

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashCaptureTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = try LibraryStore(root: root, index: SearchIndex(path: nil)) { try FileManager.default.removeItem(at: $0) }
        saver = CaptureSaver(library: store)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func save(_ content: CaptureContent?, note: String = "") async throws -> Reference? {
        try await saver.save(content.map { CaptureItem(content: $0, origin: .pasted) }, note: note)
    }

    private func fileContents(_ reference: Reference) throws -> String {
        try String(contentsOf: store.url(for: #require(reference.markdownPath)), encoding: .utf8)
    }

    @Test func youTubeTabSavesThePlayingMoment() async throws {
        let url = URL(string: "https://youtu.be/dQw4w9WgXcQ?si=share")!
        let saved = try #require(try await save(.link(url, title: "How I Write Hooks", timestamp: 272), note: "great hook #hooks #Thumbnails"))

        #expect(saved.url?.absoluteString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s")
        #expect(saved.timestamp == 272)
        #expect(saved.site == "youtube.com")
        #expect(saved.tags == ["hooks", "thumbnails"])
        #expect(saved.note == "great hook")
        #expect(try fileContents(saved).contains("url: https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s\n"))
    }

    @Test func youTubeKeepsTheURLsTimeWhenThePlayerCantBeRead() async throws {
        let url = URL(string: "https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=4m32s")!
        let saved = try #require(try await save(.link(url, title: nil, timestamp: nil)))
        #expect(saved.url?.absoluteString == "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s")
        #expect(saved.timestamp == 272)
    }

    @Test func otherLinksAreSavedAsIs() async throws {
        let url = URL(string: "https://www.nngroup.com/articles/f-shaped/?utm=x")!
        let saved = try #require(try await save(.link(url, title: "F-Shaped", timestamp: nil)))
        #expect(saved.url == url)
        #expect(saved.site == "nngroup.com")
        #expect(saved.timestamp == nil)
    }

    @Test func typedNoteAloneBecomesAText() async throws {
        let saved = try #require(try await save(nil, note: "hooks that ask a question #ideas"))
        #expect(saved.type == .text)
        #expect(saved.text == "hooks that ask a question")
        #expect(saved.note == "")
        #expect(saved.tags == ["ideas"])
    }

    @Test func nothingToSave() async throws {
        #expect(try await save(nil, note: "") == nil)
        #expect(try await save(nil, note: "  #only-tags ") == nil)
        #expect(try store.index.count() == 0)
    }

    @Test func copiedTextKeepsTheNoteSeparately() async throws {
        let saved = try #require(try await save(.text("Stop selling. Start telling."), note: "from an ad #copy"))
        #expect(saved.text == "Stop selling. Start telling.")
        #expect(saved.note == "from an ad")
        #expect(try fileContents(saved).contains("note: from an ad\n"))
    }

    @Test func imagesGoToAssetsWithTheirSize() async throws {
        let saved = try #require(try await save(.image(ClipboardReaderTests.pngData(width: 4, height: 3), fileExtension: "png")))
        #expect(saved.type == .image)
        #expect(saved.file == "assets/\(saved.id).png")
        #expect((saved.width, saved.height) == (4, 3))
        #expect(FileManager.default.fileExists(atPath: store.url(for: saved.file!).path))
    }

    @Test func filesAreCopiedIn() async throws {
        let source = root.appending(path: "Brief Q4.PDF")
        try Data("%PDF-1.4".utf8).write(to: source)

        let saved = try #require(try await save(.file(source), note: "#briefs"))
        #expect(saved.type == .file)
        #expect(saved.originalFilename == "Brief Q4.PDF")
        #expect(saved.file == "assets/\(saved.id).pdf")
        #expect(try Data(contentsOf: store.url(for: saved.file!)) == Data("%PDF-1.4".utf8))
        // The original stays where it was.
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func imageFilesBecomeImages() async throws {
        let source = root.appending(path: "ad.png")
        try ClipboardReaderTests.pngData(width: 5, height: 7).write(to: source)
        let saved = try #require(try await save(.file(source)))
        #expect(saved.type == .image)
        #expect((saved.width, saved.height) == (5, 7))
    }
}

@Suite("Capture helpers")
struct CaptureHelperTests {
    @Test func tagSuggestions() {
        let known = ["hooks", "home", "ads", "hot", "hover", "horse", "hope", "ho"]
        #expect(TagSuggestions.suggestions(for: "nice #ho", from: known) == ["hooks", "home", "hot", "hover", "horse"])
        #expect(TagSuggestions.suggestions(for: "#hooks nice #ho", from: known) == ["home", "hot", "hover", "horse", "hope"])
        #expect(TagSuggestions.suggestions(for: "nice #", from: known).count == TagSuggestions.limit)
        #expect(TagSuggestions.suggestions(for: "nice #hooks ", from: known).isEmpty)
        #expect(TagSuggestions.suggestions(for: "nice", from: known).isEmpty)
    }

    @Test func completingATag() {
        #expect(TagSuggestions.complete("nice #ho", with: "hooks") == "nice #hooks ")
        #expect(TagSuggestions.complete("#", with: "ads") == "#ads ")
    }

    @Test func tabTitles() {
        let video = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        let page = URL(string: "https://example.com/a")!
        #expect(CaptureTitle.clean("(3) How I Write Hooks - YouTube", for: video) == "How I Write Hooks")
        #expect(CaptureTitle.clean("Pricing - YouTube Help", for: page) == "Pricing - YouTube Help")
        #expect(CaptureTitle.clean("https://example.com/a", for: page) == nil)
        #expect(CaptureTitle.clean("   ", for: page) == nil)
    }
}
