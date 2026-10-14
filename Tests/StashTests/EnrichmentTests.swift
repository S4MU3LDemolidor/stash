import AppKit
import Testing
@testable import Stash

/// Enrichment without the network: the Enricher's fetch is replaced by a fake.
/// Serialized because one test turns the setting off.
@MainActor
@Suite("Enrichment", .serialized)
final class EnrichmentTests {
    let root: URL
    let store: LibraryStore
    let enricher = Enricher()
    var fetchedURLs: [URL] = []

    let found = LinkMetadata(
        title: "F-Shaped Pattern of Reading",
        thumbnail: ImageInfo.jpegData(from: ClipboardReaderTests.pngData(width: 1600, height: 900), maxPixels: 1280),
        icon: ImageInfo.pngData(from: ClipboardReaderTests.pngData(width: 128, height: 128), maxPixels: 64)
    )

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashEnrichmentTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = try LibraryStore(root: root, index: SearchIndex(path: nil)) { try FileManager.default.removeItem(at: $0) }
        enricher.library = store
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func link(title: String? = nil, tags: [String] = []) throws -> Reference {
        try store.create(Reference(
            type: .link,
            url: URL(string: "https://www.nngroup.com/articles/f-shaped/"),
            title: title,
            site: "nngroup.com",
            tags: tags
        ))
    }

    private func reloaded(_ reference: Reference) throws -> Reference {
        try #require(try store.index.reference(id: reference.id))
    }

    private func waitUntilIdle() async throws {
        for _ in 0..<200 where !enricher.inProgress.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func savesTitleThumbnailAndSiteIcon() throws {
        let saved = try link()
        enricher.apply(found, to: saved)

        let updated = try reloaded(saved)
        #expect(updated.title == "F-Shaped Pattern of Reading")
        #expect(updated.thumbnail == "assets/\(saved.id).jpg")
        #expect(ImageInfo.pixelSize(fileURL: store.url(for: updated.thumbnail!))?.width == 1280)
        #expect(store.siteIconURL(for: "nngroup.com") != nil)
        let markdown = try String(contentsOf: store.url(for: updated.markdownPath!), encoding: .utf8)
        #expect(markdown.contains("title: F-Shaped Pattern of Reading\n"))
        #expect(markdown.contains("thumbnail: assets/\(saved.id).jpg\n"))
    }

    @Test func keepsATitleItAlreadyHas() throws {
        let saved = try link(title: "From the browser tab")
        enricher.apply(found, to: saved)
        #expect(try reloaded(saved).title == "From the browser tab")
        #expect(try reloaded(saved).thumbnail != nil)
    }

    @Test func fetchesInTheBackground() async throws {
        enricher.fetch = { [weak self] url in
            self?.fetchedURLs.append(url)
            return self?.found
        }
        let saved = try link()
        enricher.enrich(saved)
        #expect(enricher.inProgress.contains(saved.id))

        try await waitUntilIdle()
        #expect(fetchedURLs == [saved.url!])
        #expect(try reloaded(saved).title == "F-Shaped Pattern of Reading")
    }

    @Test func offlineChangesNothingAndTriesAgainLater() async throws {
        enricher.fetch = { _ in nil }
        let saved = try link()
        enricher.enrich(saved)
        try await waitUntilIdle()

        #expect(try reloaded(saved).title == nil)
        let pending = try store.index.linksNeedingEnrichment(notAttemptedSince: Date(), excludingTag: SampleLibrary.tag)
        #expect(pending.map(\.id) == [saved.id])
    }

    @Test func nothingIsFetchedWhenTurnedOff() async throws {
        UserDefaults.standard.set(false, forKey: Preferences.Key.fetchMetadata)
        defer { UserDefaults.standard.removeObject(forKey: Preferences.Key.fetchMetadata) }
        enricher.fetch = { [weak self] url in
            self?.fetchedURLs.append(url)
            return self?.found
        }

        #expect(await MetadataFetcher.shared.metadata(for: URL(string: "https://example.com")!) == nil)
        let saved = try link()
        enricher.enrich(saved)
        try await waitUntilIdle()
        #expect(fetchedURLs.isEmpty)
        #expect(try reloaded(saved).title == nil)
    }

    @Test func aLinkDeletedMeanwhileLeavesNothingBehind() throws {
        let saved = try link()
        try store.delete(id: saved.id)
        enricher.apply(found, to: saved)
        #expect(!FileManager.default.fileExists(atPath: store.url(for: "assets/\(saved.id).jpg").path))
    }

    @Test func picksUpLinksStillMissingMetadata() async throws {
        enricher.fetch = { [weak self] url in
            self?.fetchedURLs.append(url)
            return self?.found
        }
        let missing = try link()
        _ = try link(tags: [SampleLibrary.tag])

        // The Enricher looks for work shortly after the library changes.
        for _ in 0..<40 where fetchedURLs.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }
        try await waitUntilIdle()
        #expect(fetchedURLs.count == 1)
        #expect(try reloaded(missing).title == "F-Shaped Pattern of Reading")

        // Done: not picked up again.
        let pending = try store.index.linksNeedingEnrichment(
            notAttemptedSince: Date().addingTimeInterval(-60), excludingTag: SampleLibrary.tag
        )
        #expect(pending.isEmpty)
    }
}

@Suite("Enrichment helpers")
struct EnrichmentHelperTests {
    @Test func reencodesImagesWithinASize() throws {
        let png = ClipboardReaderTests.pngData(width: 3000, height: 1500)
        let jpeg = try #require(ImageInfo.jpegData(from: png, maxPixels: 1280))
        #expect(jpeg.starts(with: [0xFF, 0xD8]))
        #expect(ImageInfo.pixelSize(data: jpeg).map { [$0.width, $0.height] } == [1280, 640])

        let icon = try #require(ImageInfo.pngData(from: png, maxPixels: 64))
        #expect(ImageInfo.pixelSize(data: icon)?.width == 64)
        #expect(ImageInfo.jpegData(from: Data("not an image".utf8), maxPixels: 10) == nil)
    }

    @Test func youTubeOEmbed() {
        #expect(YouTube.oEmbedURL(videoID: "dQw4w9WgXcQ").absoluteString
            == "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v%3DdQw4w9WgXcQ&format=json")
        #expect(YouTube.title(fromOEmbed: Data(#"{"title":" Me at the zoo ","author_name":"jawed"}"#.utf8)) == "Me at the zoo")
        #expect(YouTube.title(fromOEmbed: Data("Not Found".utf8)) == nil)
        #expect(YouTube.thumbnailURLs(videoID: "abc").first?.absoluteString == "https://i.ytimg.com/vi/abc/maxresdefault.jpg")
    }

    @Test func linksWithoutATitleShowTheirURL() {
        let link = Reference(type: .link, url: URL(string: "https://www.nngroup.com/articles/f-shaped/?ref=x"))
        #expect(link.displayTitle == "nngroup.com/articles/f-shaped/")
        #expect(Reference(type: .link, url: URL(string: "https://example.com/")).displayTitle == "example.com")
    }
}
