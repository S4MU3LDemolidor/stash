import Foundation
import Testing
@testable import Stash

@Suite("Search")
struct SearchTests {
    let index: SearchIndex
    let hooksVideo: Reference
    let quote: Reference
    let adImage: Reference
    let promo: Reference

    init() throws {
        index = try SearchIndex(path: nil)
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        promo = Self.make(Reference(
            type: .link, created: base,
            url: URL(string: "https://loja.com.br/natal"), title: "Promoção de Natal", site: "loja.com.br",
            tags: ["ads"]
        ))
        adImage = Self.make(Reference(
            type: .image, created: base + 60,
            file: "assets/C.png", tags: ["ads", "hooks"], note: "Black Friday ad"
        ))
        quote = Self.make(Reference(
            type: .text, created: base + 120,
            tags: ["copy"], text: "Stop selling, start telling"
        ))
        hooksVideo = Self.make(Reference(
            type: .link, created: base + 180,
            url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
            title: "How I Write Hooks That Stop the Scroll", site: "youtube.com", timestamp: 272,
            tags: ["hooks", "thumbnails"], note: "great hook in the first 3s"
        ))
        for reference in [promo, adImage, quote, hooksVideo] {
            try index.upsert(reference, stamp: FileStamp(modified: 0, size: 0))
        }
    }

    private static func make(_ reference: Reference) -> Reference {
        var reference = reference
        reference.markdownPath = "items/\(reference.id).md"
        return reference
    }

    private func ids(_ text: String) throws -> [String] {
        try index.search(SearchQuery.parse(text)).map(\.id)
    }

    @Test func emptyQueryListsEverythingNewestFirst() throws {
        #expect(try ids("") == [hooksVideo, quote, adImage, promo].map(\.id))
    }

    @Test func matchesPrefixesAsYouType() throws {
        #expect(try ids("h") == [hooksVideo.id, adImage.id])
        #expect(try ids("hoo") == [hooksVideo.id, adImage.id])
        #expect(try ids("tell") == [quote.id])
    }

    @Test func titleMatchesRankAboveOtherFields() throws {
        // "stop" is in the video title and in the quote's text.
        #expect(try ids("stop") == [hooksVideo.id, quote.id])
    }

    @Test func everyTermMustMatch() throws {
        #expect(try ids("black ad") == [adImage.id])
        #expect(try ids("black scroll").isEmpty)
    }

    @Test func searchesNotesSitesAndURLs() throws {
        #expect(try ids("first 3s") == [hooksVideo.id])
        #expect(try ids("loja") == [promo.id])
        #expect(try ids("youtube.com") == [hooksVideo.id])
    }

    @Test func ignoresAccents() throws {
        #expect(try ids("promocao") == [promo.id])
        #expect(try ids("promoção") == [promo.id])
    }

    @Test func filtersByTag() throws {
        #expect(try ids("#hooks") == [hooksVideo.id, adImage.id])
        #expect(try ids("#hooks #ads") == [adImage.id])
        #expect(try ids("#HOOKS black") == [adImage.id])
        #expect(try ids("#nothing").isEmpty)
    }

    @Test func filtersByType() throws {
        #expect(try ids("type:image") == [adImage.id])
        #expect(try ids("type:links") == [hooksVideo.id, promo.id])
        #expect(try ids("#ads type:link") == [promo.id])
        #expect(try ids("hooks type:text").isEmpty)
    }

    @Test func oddInputDoesntBreakTheQuery() throws {
        #expect(try ids("\"") == [hooksVideo, quote, adImage, promo].map(\.id))
        #expect(try ids("AND OR NOT ( * -").isEmpty)
        #expect(try ids("hoo\"ks").isEmpty)
    }

    @Test func updatesAndRemovalsAreReflected() throws {
        var renamed = quote
        renamed.text = "Brand new words"
        try index.upsert(renamed, stamp: FileStamp(modified: 1, size: 1))
        #expect(try ids("selling").isEmpty)
        #expect(try ids("brand") == [quote.id])

        try index.remove(id: quote.id)
        #expect(try ids("brand").isEmpty)
        #expect(try index.count() == 3)
    }

    @Test func tagUsageCounts() throws {
        let tags = try index.tags()
        #expect(tags.prefix(2).map(\.name) == ["ads", "hooks"])
        #expect(tags.first?.count == 2)
    }

    @Test func returnsAllStoredFields() throws {
        #expect(try index.reference(id: hooksVideo.id) == hooksVideo)
    }

    @Test func queryParsing() {
        let query = SearchQuery.parse("hooks #Thumbnails type:images  foo # type: type:video")
        #expect(query.terms == ["hooks", "foo", "type:video"])
        #expect(query.tags == ["thumbnails"])
        #expect(query.types == [.image])
        #expect(SearchQuery.parse("say \"hi\"").ftsPattern == "\"say\"* \"\"\"hi\"\"\"*")
    }
}
