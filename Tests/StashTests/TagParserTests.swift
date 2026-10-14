import Testing
@testable import Stash

@Suite("Tag parser")
struct TagParserTests {
    @Test func splitsNoteAndTags() {
        let result = TagParser.parse("great hook in the first 3s #hooks #thumbnails")
        #expect(result == .init(text: "great hook in the first 3s", tags: ["hooks", "thumbnails"]))
    }

    @Test func tagsAnywhereInTheNote() {
        let result = TagParser.parse("#ads Black Friday #promo ad")
        #expect(result == .init(text: "Black Friday ad", tags: ["ads", "promo"]))
    }

    @Test func lowercasesAndRemovesDuplicates() {
        #expect(TagParser.parse("#Hooks #hooks #HOOKS").tags == ["hooks"])
    }

    @Test func supportsAccentsNestingAndSeparators() {
        #expect(TagParser.parse("#ação #design/ads #black-friday #q4_2026").tags
            == ["ação", "design/ads", "black-friday", "q4_2026"])
    }

    @Test func numbersAloneAreNotTags() {
        let result = TagParser.parse("top #1 idea of #2024 #2024-plan")
        #expect(result == .init(text: "top #1 idea of #2024", tags: ["2024-plan"]))
    }

    @Test func hashInsideAWordIsNotATag() {
        #expect(TagParser.parse("C# and example.com/page#section").tags.isEmpty)
    }

    @Test func keepsPunctuationAfterATag() {
        #expect(TagParser.parse("loved it #hooks, really").text == "loved it , really")
    }

    @Test func emptyAndTagOnlyNotes() {
        #expect(TagParser.parse("") == .init(text: "", tags: []))
        #expect(TagParser.parse("  #hooks  ") == .init(text: "", tags: ["hooks"]))
    }

    @Test func normalize() {
        #expect(TagParser.normalize("#Hooks") == "hooks")
        #expect(TagParser.normalize("hooks") == "hooks")
        #expect(TagParser.normalize("two words") == nil)
        #expect(TagParser.normalize("#") == nil)
        #expect(TagParser.normalize("123") == nil)
    }

    @Test func partialTagForAutocomplete() {
        #expect(TagParser.partialTag(atEndOf: "nice #ho") == "ho")
        #expect(TagParser.partialTag(atEndOf: "nice #") == "")
        #expect(TagParser.partialTag(atEndOf: "nice #hooks ") == nil)
        #expect(TagParser.partialTag(atEndOf: "nice") == nil)
    }
}
