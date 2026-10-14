import Foundation
import Testing
@testable import Stash

@Suite("Markdown codec")
struct MarkdownCodecTests {
    let brazil = TimeZone(secondsFromGMT: -3 * 3600)!

    /// The example from what-the-app-is.md, verbatim.
    let docExample = """
        ---
        id: 01JA8K3Q7Z2M4X5C6V7B8N9P0Q
        type: link
        url: https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s
        title: How I Write Hooks That Stop the Scroll
        site: youtube.com
        timestamp: 272
        tags: [hooks, thumbnails]
        thumbnail: assets/01JA8K3Q7Z2M4X5C6V7B8N9P0Q.jpg
        created: 2026-10-14T10:20:00-03:00
        ---
        great hook in the first 3s

        """

    var docReference: Reference {
        Reference(
            id: "01JA8K3Q7Z2M4X5C6V7B8N9P0Q",
            type: .link,
            created: MarkdownCodec.parseDate("2026-10-14T10:20:00-03:00")!,
            url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
            title: "How I Write Hooks That Stop the Scroll",
            site: "youtube.com",
            timestamp: 272,
            thumbnail: "assets/01JA8K3Q7Z2M4X5C6V7B8N9P0Q.jpg",
            tags: ["hooks", "thumbnails"],
            note: "great hook in the first 3s"
        )
    }

    @Test func encodesTheDocumentedFormatExactly() {
        #expect(MarkdownCodec.encode(docReference, timeZone: brazil) == docExample)
    }

    @Test func decodesTheDocumentedFormat() throws {
        #expect(try MarkdownCodec.decode(docExample) == docReference)
    }

    @Test func textReferenceKeepsTextInBodyAndNoteInFrontMatter() throws {
        let reference = Reference(
            type: .text,
            created: Reference.now(),
            tags: ["copy"],
            note: "from the Nike ad",
            text: "Stop selling.\n\nStart telling."
        )
        let markdown = MarkdownCodec.encode(reference)
        #expect(markdown.contains("note: from the Nike ad\n"))
        #expect(markdown.hasSuffix("---\nStop selling.\n\nStart telling.\n"))
        #expect(try MarkdownCodec.decode(markdown) == reference)
    }

    @Test(arguments: [
        "Hooks: part 2",
        "\"Quoted\" title",
        "- starts with a dash",
        "#1 hook",
        "Episode #5",
        "2024",
        "yes",
        "Line one\nLine two",
        "Tab\there",
        "Ends with colon:",
        "C:\\path\\to",
        "Ação de Natal 🎄",
        " padded ",
        "it's",
    ])
    func titlesRoundTrip(title: String) throws {
        let reference = Reference(type: .link, url: URL(string: "https://example.com"), title: title)
        let decoded = try MarkdownCodec.decode(MarkdownCodec.encode(reference))
        // Surrounding whitespace isn't meaningful in a title.
        #expect(decoded.title == title.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test func imageAndFileFieldsRoundTrip() throws {
        let image = Reference(type: .image, file: "assets/A.png", width: 1080, height: 1350, tags: ["ads"], note: "Black Friday ad")
        #expect(try MarkdownCodec.decode(MarkdownCodec.encode(image)) == image)

        let file = Reference(type: .file, file: "assets/B.pdf", originalFilename: "Brief: Q4.pdf")
        #expect(try MarkdownCodec.decode(MarkdownCodec.encode(file)) == file)
    }

    @Test func readsWhatObsidianWrites() throws {
        let markdown = "---\r\nid: 01JA8K3Q7Z2M4X5C6V7B8N9P0Q\r\ntype: link\r\nurl: https://example.com\r\n"
            + "title: 'It''s here'\r\ntags:\r\n  - Hooks\r\n  - \"ads\"\r\n"
            + "created: 2026-10-14T10:20:00.123Z\r\n---\r\nA note\r\n"
        let reference = try MarkdownCodec.decode(markdown)
        #expect(reference.title == "It's here")
        #expect(reference.tags == ["hooks", "ads"])
        #expect(reference.note == "A note")
    }

    @Test func keepsUnknownFieldsVerbatim() throws {
        let markdown = """
            ---
            id: 01JA8K3Q7Z2M4X5C6V7B8N9P0Q
            type: link
            url: https://example.com
            tags: []
            rating: 5
            aliases:
              - one
              - two
            created: 2026-10-14T10:20:00-03:00
            ---
            note

            """
        var reference = try MarkdownCodec.decode(markdown)
        #expect(reference.extraFields.map(\.key) == ["rating", "aliases"])

        reference.note = "changed"
        let encoded = MarkdownCodec.encode(reference, timeZone: brazil)
        #expect(encoded.contains("rating: 5\naliases:\n  - one\n  - two\n---\nchanged\n"))
    }

    @Test func infersMissingTypeAndUsesFallbackDate() throws {
        let fallback = Date(timeIntervalSince1970: 1_800_000_000)
        let reference = try MarkdownCodec.decode(
            "---\nid: X\nurl: https://example.com\n---\n",
            fallbackCreated: fallback
        )
        #expect(reference.type == .link)
        #expect(reference.created == fallback)
    }

    @Test func rejectsFilesItCantUnderstand() {
        #expect(throws: MarkdownCodec.DecodeError.missingFrontMatter) {
            try MarkdownCodec.decode("Just some text")
        }
        #expect(throws: MarkdownCodec.DecodeError.missingField("id")) {
            try MarkdownCodec.decode("---\ntype: link\ncreated: 2026-10-14T10:20:00Z\n---\n")
        }
        #expect(throws: MarkdownCodec.DecodeError.invalidField("type")) {
            try MarkdownCodec.decode("---\nid: X\ntype: video\ncreated: 2026-10-14T10:20:00Z\n---\n")
        }
    }
}
