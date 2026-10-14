import AppKit
import Testing
@testable import Stash

@Suite("Library formatting")
struct LibraryFormattingTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    let now = MarkdownCodec.parseDate("2026-10-14T15:00:00Z")!

    private func reference(hoursAgo: Double, title: String = "x") -> Reference {
        Reference(type: .link, created: now.addingTimeInterval(-hoursAgo * 3600), title: title)
    }

    @Test func groupsByDayWhenBrowsing() {
        let refs = [reference(hoursAgo: 1), reference(hoursAgo: 20), reference(hoursAgo: 72), reference(hoursAgo: 24 * 30)]
        let sections = LibraryFormatting.sections(for: refs, searching: false, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["Today", "Yesterday", "This Week", "Earlier"])
        #expect(sections.map(\.items.count) == [1, 1, 1, 1])
    }

    @Test func searchResultsAreOneSection() {
        let refs = [reference(hoursAgo: 1), reference(hoursAgo: 24 * 30)]
        #expect(LibraryFormatting.sections(for: refs, searching: true, now: now, calendar: calendar).map(\.title) == ["Results"])
        #expect(LibraryFormatting.sections(for: [], searching: false, now: now, calendar: calendar).isEmpty)
    }

    @Test func relativeDates() {
        func relative(_ hoursAgo: Double) -> String {
            LibraryFormatting.relativeDate(now.addingTimeInterval(-hoursAgo * 3600), now: now, calendar: calendar)
        }
        #expect(relative(0.001) == "just now")
        #expect(relative(0.25) == "15m ago")
        #expect(relative(2) == "2h ago")
        #expect(relative(20) == "Yesterday")
        #expect(relative(24 * 400).contains("2025"))
    }

    @Test func titlesAndSubtitles() {
        let video = Reference(
            type: .link, url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
            title: "Hooks", site: "youtube.com", timestamp: 272
        )
        #expect(video.displayTitle == "Hooks")
        #expect(video.displaySubtitle == "youtube.com · at 4:32")
        #expect(video.kindDescription == "YouTube video")

        let text = Reference(type: .text, note: "from an ad", text: "Stop selling.\nStart telling.")
        #expect(text.displayTitle == "Stop selling.")
        #expect(text.displaySubtitle == "from an ad")

        let image = Reference(type: .image, width: 1080, height: 1350, note: "Black Friday ad")
        #expect(image.displayTitle == "Black Friday ad")
        #expect(image.displaySubtitle == "Image · 1080×1350")

        #expect(video.accessibilityDescription(now: video.created) == "YouTube video, Hooks, saved just now")
    }
}

@MainActor
@Suite("Library controller")
final class LibraryControllerTests {
    let root: URL
    let store: LibraryStore
    let controller = LibraryController()

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashLibraryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = try LibraryStore(root: root, index: SearchIndex(path: nil)) { try FileManager.default.removeItem(at: $0) }
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        try store.create([
            Reference(type: .link, created: base, url: URL(string: "https://a.com"), title: "Alpha hooks", tags: ["hooks"]),
            Reference(type: .text, created: base + 60, tags: ["copy"], text: "Beta words"),
            Reference(type: .image, created: base + 120, tags: ["hooks", "ads"], note: "Gamma ad"),
        ])
        controller.library = store
        controller.reset()
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private var titles: [String] { controller.results.map(\.displayTitle) }

    @Test func listsNewestFirstAndSelectsTheFirst() {
        #expect(titles == ["Gamma ad", "Beta words", "Alpha hooks"])
        #expect(controller.selected?.displayTitle == "Gamma ad")
        #expect(controller.sections.count == 1)
    }

    @Test func finishedFilterTokensBecomePills() {
        controller.searchText = "#hooks gam"
        // Not finished: "#hooks" is followed by a space, so it is.
        #expect(controller.pills == [.tag("hooks")])
        #expect(controller.searchText == "gam")
        #expect(titles == ["Gamma ad"])
        #expect(controller.isSearching)

        controller.searchText = "gam type:image "
        #expect(controller.pills == [.tag("hooks"), .type(.image)])
        #expect(controller.searchText == "gam ")
    }

    @Test func aFilterStillBeingTypedIsIgnored() {
        controller.searchText = "#hoo"
        #expect(controller.pills.isEmpty)
        #expect(controller.results.count == 3)
        #expect(controller.autocomplete.suggestions == ["hooks"])

        #expect(controller.completeTagSuggestion())
        #expect(controller.pills == [.tag("hooks")])
        #expect(controller.searchText == "")
        #expect(titles == ["Gamma ad", "Alpha hooks"])
    }

    @Test func backspaceAndEscapeClearFilters() {
        controller.searchText = "#hooks "
        #expect(controller.removeLastPill())
        #expect(controller.pills.isEmpty)
        #expect(!controller.removeLastPill())

        controller.searchText = "beta"
        #expect(controller.clearSearch())
        #expect(controller.searchText.isEmpty)
        #expect(!controller.clearSearch())
    }

    @Test func movesThroughTheListAndGrid() {
        controller.moveSelection(.down)
        #expect(controller.selected?.displayTitle == "Beta words")
        controller.moveSelection(.down)
        controller.moveSelection(.down)
        #expect(controller.selected?.displayTitle == "Alpha hooks")

        controller.layout = .grid
        controller.moveSelection(.up)
        #expect(controller.selected?.displayTitle == "Gamma ad")
        controller.moveSelection(.right)
        #expect(controller.selected?.displayTitle == "Beta words")
        controller.layout = .list
    }

    @Test func deleteKeepsTheSelectionInPlace() throws {
        controller.moveSelection(.down)
        controller.requestDelete()
        #expect(controller.deleteCandidate?.displayTitle == "Beta words")
        try controller.confirmDelete()
        #expect(titles == ["Gamma ad", "Alpha hooks"])
        #expect(controller.selected?.displayTitle == "Alpha hooks")
    }

    @Test func editingUpdatesNoteAndTags() throws {
        controller.beginEdit()
        #expect(controller.editText == "Gamma ad #hooks #ads ")
        controller.editText = "Gamma ad, edited #ads #promo"
        try controller.commitEdit()
        #expect(controller.editing == nil)
        let updated = try #require(controller.selected)
        #expect(updated.note == "Gamma ad, edited")
        #expect(updated.tags == ["ads", "promo"])
    }

    @Test func noResultsSavesTheSearchAsANote() throws {
        controller.searchText = "#ideas "
        controller.searchText = "a brand new thought"
        #expect(controller.results.isEmpty)
        try controller.saveSearchAsNote()
        #expect(controller.searchText.isEmpty)
        #expect(controller.pills.isEmpty)
        let saved = try #require(controller.selected)
        #expect(saved.text == "a brand new thought")
        #expect(saved.tags == ["ideas"])
    }
}

@MainActor
@Suite("Search inside files and sample data")
final class FileSearchTests {
    let root: URL
    let store: LibraryStore

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashFileTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = try LibraryStore(root: root, index: SearchIndex(path: nil)) { try FileManager.default.removeItem(at: $0) }
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func pdf(saying text: String) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 400, height: 200)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        (text as NSString).draw(at: CGPoint(x: 20, y: 100), withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    @Test func extractsTextFromPDFsAndTextFiles() throws {
        let pdfURL = root.appending(path: "brief.pdf")
        try pdf(saying: "Quarterly budget forecast").write(to: pdfURL)
        #expect(FileTextExtractor.text(of: pdfURL)?.contains("Quarterly budget forecast") == true)

        let textURL = root.appending(path: "notes.md")
        try Data("# Hooks\nAsk a question".utf8).write(to: textURL)
        #expect(FileTextExtractor.text(of: textURL) == "# Hooks\nAsk a question")

        #expect(FileTextExtractor.text(of: root.appending(path: "photo.png")) == nil)
    }

    @Test func savedFilesAreSearchableByTheirContents() async throws {
        var reference = Reference(type: .file, originalFilename: "brief.pdf")
        reference.file = try store.saveAsset(pdf(saying: "Quarterly budget forecast"), id: reference.id, fileExtension: "pdf")
        try store.create(reference)

        // Text extraction runs in the background.
        var found: [Reference] = []
        for _ in 0..<50 where found.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
            found = try store.index.search(SearchQuery.parse("forecast"))
        }
        #expect(found.map(\.id) == [reference.id])
    }

    @Test func sampleLibraryIsQuickToSearch() throws {
        try SampleLibrary.generate(into: store)
        #expect(try store.index.count() == 200)
        #expect(try store.index.search(SearchQuery(tags: [SampleLibrary.tag])).count == 200)

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for query in ["h", "ho", "hoo", "hook", "hooks", "#ads ", "type:image", "budget"] {
                _ = try store.index.search(SearchQuery.parse(query))
            }
        }
        #expect(elapsed < .milliseconds(200), "8 searches took \(elapsed)")
    }

    @Test func largeIndexStillSearchesPerKeystroke() throws {
        let index = try SearchIndex(path: nil)
        let words = ["hook", "thumbnail", "editing", "pricing", "brand", "motion", "color", "copy"]
        let upserts = (0..<5000).map { i in
            var reference = Reference(
                type: .link, created: Date(timeIntervalSince1970: Double(1_800_000_000 + i)),
                url: URL(string: "https://example.com/\(i)"), title: "\(words[i % 8]) idea \(i)", site: "example.com",
                tags: [words[(i / 8) % 8]], note: "note about \(words[(i / 3) % 8])"
            )
            reference.markdownPath = "items/\(i).md"
            return SearchIndex.Upsert(reference: reference, stamp: FileStamp(modified: 0, size: 0))
        }
        try index.apply(upserts: upserts, removedPaths: [])

        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            for query in ["t", "th", "thu", "thum", "thumb", "#brand thumb", ""] {
                _ = try index.search(SearchQuery.parse(query))
            }
        }
        // Seven keystrokes over 5,000 references: about 16 ms each on an M-series Mac. The bound
        // leaves room for slower CI machines while still meaning "instant".
        #expect(elapsed < .milliseconds(700), "7 searches took \(elapsed)")
    }
}
