import AppKit
import Testing
@testable import Stash

/// Named pasteboards and a throwaway shelf; never the user's clipboard or shelf.
@MainActor
@Suite("Shelf drops and drags")
final class ShelfPasteboardTests {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("dev.stash.tests.shelf.\(UUID().uuidString)"))
    let root = FileManager.default.temporaryDirectory.appending(path: "ShelfPB-\(UUID().uuidString)", directoryHint: .isDirectory)
    let store: ShelfStore

    init() throws {
        pasteboard.clearContents()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = ShelfStore(folder: root.appending(path: "Shelf", directoryHint: .isDirectory))
    }

    deinit {
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: root)
    }

    @Test func severalFilesAndFoldersBecomeReferences() throws {
        let file = root.appending(path: "cut.mov")
        try Data("x".utf8).write(to: file)
        let folder = root.appending(path: "Moodboard", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        pasteboard.writeObjects([file as NSURL, folder as NSURL])
        let items = try ShelfPasteboard.items(from: pasteboard, store: store)
        #expect(items.map(\.name) == ["cut.mov", "Moodboard"])
        #expect(items.map(\.isFolder) == [false, true])
    }

    @Test func anImageBecomesAPrivateCopy() throws {
        pasteboard.setData(ClipboardReaderTests.pngData(), forType: .png)
        let items = try ShelfPasteboard.items(from: pasteboard, store: store)
        #expect(items.count == 1)
        guard case .stored(let fileName, .image)? = items.first?.kind else {
            Issue.record("Expected a stored image, got \(String(describing: items.first?.kind))")
            return
        }
        #expect(FileManager.default.fileExists(atPath: store.itemsFolder.appending(path: fileName).path))
    }

    @Test func aLinkKeepsItsTitle() throws {
        pasteboard.declareTypes([.string, ShelfPasteboard.urlName], owner: nil)
        pasteboard.setString("https://example.com/teardown", forType: .string)
        pasteboard.setString("Landing Page Teardown", forType: ShelfPasteboard.urlName)
        let items = try ShelfPasteboard.items(from: pasteboard, store: store)
        #expect(items.first?.name == "Landing Page Teardown")
        #expect(items.first?.kind == .link(URL(string: "https://example.com/teardown")!, title: "Landing Page Teardown"))
    }

    @Test func textBecomesAPrivateCopyNamedByItsFirstLine() throws {
        pasteboard.setString("Make the viewer the hero\nnot the brand", forType: .string)
        let items = try ShelfPasteboard.items(from: pasteboard, store: store)
        #expect(items.first?.name == "Make the viewer the hero")
        guard case .stored(_, .text)? = items.first?.kind else {
            Issue.record("Expected stored text")
            return
        }
    }

    @Test func passwordManagerItemsAreRefused() throws {
        pasteboard.declareTypes([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("hunter2", forType: .string)
        #expect(try ShelfPasteboard.items(from: pasteboard, store: store).isEmpty)
    }

    @Test func itemsGoBackOutWithTheRightTypes() throws {
        let copy = try store.storeCopy(Data("a note".utf8), fileExtension: "txt")
        let text = ShelfItem(name: "a note", kind: .stored(fileName: copy, type: .text))
        let link = ShelfItem(name: "Example", kind: .link(URL(string: "https://example.com")!, title: "Example"))
        store.add([text, link])

        pasteboard.clearContents()
        pasteboard.writeObjects(ShelfPasteboard.writers(for: [text], store: store))
        #expect(pasteboard.string(forType: .string) == "a note")
        #expect(pasteboard.availableType(from: [.fileURL]) != nil)

        pasteboard.clearContents()
        pasteboard.writeObjects(ShelfPasteboard.writers(for: [link], store: store))
        #expect(pasteboard.string(forType: .URL) == "https://example.com")
        #expect(pasteboard.string(forType: ShelfPasteboard.urlName) == "Example")
    }
}
