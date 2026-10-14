import Foundation
import Testing
@testable import Stash

@Suite("Slugs and file names")
struct SlugTests {
    @Test func basicSlug() {
        #expect(Slug.make("great hook in the first 3s") == "great-hook-in-the-first-3s")
    }

    @Test func foldsAccentsAndDropsPunctuation() {
        #expect(Slug.make("Ação: promoção de Natal!") == "acao-promocao-de-natal")
        #expect(Slug.make("  --Hello,   World--  ") == "hello-world")
    }

    @Test func nothingUsableGivesEmptySlug() {
        #expect(Slug.make("!!! ???") == "")
    }

    @Test func cutsLongTextAtAWordBoundary() {
        let slug = Slug.make("How I write hooks that stop the scroll and keep people watching until the end")
        #expect(slug.count <= Slug.maxLength)
        #expect(slug == "how-i-write-hooks-that-stop-the-scroll-and-keep")
        #expect(!slug.hasSuffix("-"))
    }

    @Test func cutsALongSingleWord() {
        #expect(Slug.make(String(repeating: "a", count: 80)).count == Slug.maxLength)
    }

    @Test func filenameUsesDateAndNoteBeforeTitle() {
        let reference = Reference(type: .link, created: date("2026-10-14T15:00:00Z"), title: "Some title", note: "great hook")
        #expect(Slug.filename(for: reference, calendar: utc) { _ in false } == "2026-10-14-great-hook.md")
    }

    @Test func filenameFallsBackToTitleThenType() {
        let titled = Reference(type: .link, created: date("2026-10-14T15:00:00Z"), title: "Black Friday ad")
        #expect(Slug.filename(for: titled, calendar: utc) { _ in false } == "2026-10-14-black-friday-ad.md")

        let bare = Reference(type: .image, created: date("2026-10-14T15:00:00Z"))
        #expect(Slug.filename(for: bare, calendar: utc) { _ in false } == "2026-10-14-image.md")
    }

    @Test func filenameIsDeduplicated() {
        let reference = Reference(type: .text, created: date("2026-10-14T15:00:00Z"), text: "Idea")
        let taken: Set = ["2026-10-14-idea.md", "2026-10-14-idea-2.md"]
        #expect(Slug.filename(for: reference, calendar: utc) { taken.contains($0) } == "2026-10-14-idea-3.md")
    }

    @Test func filenameDateFollowsTheLocalCalendar() {
        // 01:00 UTC on the 15th is still the 14th in Brazil.
        var brazil = Calendar(identifier: .gregorian)
        brazil.timeZone = TimeZone(secondsFromGMT: -3 * 3600)!
        let reference = Reference(type: .text, created: date("2026-10-15T01:00:00Z"), text: "late")
        #expect(Slug.filename(for: reference, calendar: brazil) { _ in false } == "2026-10-14-late.md")
    }

    @Test func ulidsAreValidAndSortByTime() {
        let earlier = ULID.generate(date: date("2026-10-14T10:00:00Z"))
        let later = ULID.generate(date: date("2026-10-14T10:00:01Z"))
        #expect(ULID.isValid(earlier))
        #expect(earlier < later)
        #expect(ULID.generate() != ULID.generate())
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ string: String) -> Date {
        MarkdownCodec.parseDate(string)!
    }
}
