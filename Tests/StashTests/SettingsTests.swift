import AppKit
import Testing
@testable import Stash

@MainActor
@Suite("Moving the library")
final class LibraryMoverTests {
    let base: URL
    let old: URL
    let new: URL

    init() throws {
        base = FileManager.default.temporaryDirectory
            .appending(path: "StashMoveTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        old = base.appending(path: "Stash Library", directoryHint: .isDirectory)
        new = base.appending(path: "iCloud/Stash", directoryHint: .isDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: base)
    }

    private func store(at root: URL, index: SearchIndex) throws -> LibraryStore {
        try LibraryStore(root: root, index: index) { try FileManager.default.removeItem(at: $0) }
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func plans() throws {
        let library = try store(at: old, index: SearchIndex(path: nil))
        try library.create(Reference(type: .text, text: "one"))
        try library.create(Reference(type: .text, text: "two"))

        #expect(try LibraryMover.plan(from: old, to: old) == .none)
        #expect(try LibraryMover.plan(from: old, to: new) == .move(referenceCount: 2))
        #expect(throws: LibraryMover.MoveError.self) {
            try LibraryMover.plan(from: self.old, to: self.old.appending(path: "items"))
        }

        try write("---\nid: X\ntype: text\ncreated: 2026-10-14T10:00:00Z\n---\nfrom another Mac\n", to: new.appending(path: "items/x.md"))
        #expect(try LibraryMover.plan(from: old, to: new) == .switchToExisting(referenceCount: 1))
    }

    @Test func movesEverythingAndTheLibraryKeepsWorking() throws {
        let index = try SearchIndex(path: nil)
        let library = try store(at: old, index: index)
        var image = Reference(type: .image, note: "Black Friday ad")
        image.file = try library.saveAsset(ClipboardReaderTests.pngData(), id: image.id, fileExtension: "png")
        try library.create(image)
        try library.create(Reference(type: .text, tags: ["ideas"], text: "Hooks that ask a question"))
        try library.saveSiteIcon(ClipboardReaderTests.pngData(), site: "youtube.com")

        try LibraryMover.move(from: old, to: new)
        #expect(!FileManager.default.fileExists(atPath: old.path))

        let moved = try store(at: new, index: index)
        try moved.syncNow()
        #expect(try index.count() == 2)
        #expect(try index.search(SearchQuery.parse("#ideas")).first?.text == "Hooks that ask a question")
        #expect(FileManager.default.fileExists(atPath: moved.url(for: image.file!).path))
        #expect(moved.siteIconURL(for: "youtube.com") != nil)
    }

    @Test func mergingNeverOverwrites() throws {
        try write("old a", to: old.appending(path: "assets/a.png"))
        try write("old icon", to: old.appending(path: "assets/icons/x.com.png"))
        try write("old b", to: old.appending(path: "assets/b.png"))
        try write("new a", to: new.appending(path: "assets/a.png"))
        try write("new icon dir", to: new.appending(path: "assets/icons/y.com.png"))

        try LibraryMover.move(from: old, to: new)

        #expect(try String(contentsOf: new.appending(path: "assets/a.png"), encoding: .utf8) == "new a")
        #expect(try String(contentsOf: new.appending(path: "assets/b.png"), encoding: .utf8) == "old b")
        #expect(FileManager.default.fileExists(atPath: new.appending(path: "assets/icons/x.com.png").path))
        // The conflicting file stays behind in the old folder rather than being lost.
        #expect(FileManager.default.fileExists(atPath: old.appending(path: "assets/a.png").path))
    }
}

@Suite("Accessibility")
struct ContrastTests {
    /// WCAG relative luminance of an sRGB color.
    private func luminance(_ color: NSColor) -> Double {
        let rgb = color.usingColorSpace(.sRGB)!
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
    }

    /// `text` (with alpha) drawn over an opaque `background`.
    private func contrast(_ text: NSColor, on background: NSColor) -> Double {
        let t = text.usingColorSpace(.sRGB)!, b = background.usingColorSpace(.sRGB)!
        let a = t.alphaComponent
        let blended = NSColor(
            srgbRed: t.redComponent * a + b.redComponent * (1 - a),
            green: t.greenComponent * a + b.greenComponent * (1 - a),
            blue: t.blueComponent * a + b.blueComponent * (1 - a),
            alpha: 1
        )
        let (l1, l2) = (luminance(blended), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// design.md §9: text meets WCAG AA (4.5:1) against the tint, text.secondary in light mode especially.
    @Test func textMeetsAAOnTheTint() {
        for (text, name) in [(Palette.textPrimary, "primary"), (Palette.textSecondary, "secondary")] {
            #expect(contrast(text.light, on: Palette.tint.opaque.light) >= 4.5, "light \(name)")
            #expect(contrast(text.dark, on: Palette.tint.opaque.dark) >= 4.5, "dark \(name)")
        }
    }
}
