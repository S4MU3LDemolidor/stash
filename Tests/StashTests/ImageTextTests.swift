import AppKit
import Foundation
import Testing
@testable import Stash

/// Throwaway libraries and images rendered on the fly.
@MainActor
@Suite("Text in images")
final class ImageTextTests {
    let root: URL
    let index: SearchIndex
    let store: LibraryStore

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StashImageText-\(UUID().uuidString)", directoryHint: .isDirectory)
        index = try SearchIndex(path: nil)
        store = try LibraryStore(root: root, index: index) { try FileManager.default.removeItem(at: $0) }
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    /// Black text on white, big enough for Vision.
    nonisolated static func textImage(_ text: String?, width: Int = 1000, height: Int = 220) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        if let text {
            (text as NSString).draw(
                at: NSPoint(x: 40, y: 70),
                withAttributes: [.font: NSFont.boldSystemFont(ofSize: 64), .foregroundColor: NSColor.black]
            )
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    private func saveImage(_ data: Data) throws -> Reference {
        var reference = Reference(type: .image)
        reference.file = try store.saveAsset(data, id: reference.id, fileExtension: "png")
        return try store.create(reference)
    }

    @Test func readsTheTextInAnImage() throws {
        let url = root.appending(path: "sale.png")
        try Self.textImage("BLACK FRIDAY 50% OFF").write(to: url)
        let text = try #require(ImageTextRecognizer.text(in: url))
        #expect(text.localizedCaseInsensitiveContains("black friday"))
    }

    @Test func aBlankImageHasNoText() throws {
        let url = root.appending(path: "blank.png")
        try Self.textImage(nil).write(to: url)
        #expect(ImageTextRecognizer.text(in: url) == nil)
    }

    @Test func imagesWaitUntilTheirTextIsRead() throws {
        let image = try saveImage(Self.textImage(nil))
        #expect(try index.imagesNeedingText().map(\.id) == [image.id])

        try index.setFileText("", id: image.id)
        #expect(try index.imagesNeedingText().isEmpty)
        #expect(try index.fileText(id: image.id) == nil)

        try index.setFileText("Summer Sale", id: image.id)
        #expect(try index.fileText(id: image.id) == "Summer Sale")
    }

    @Test func editingAnImageKeepsItsText() throws {
        let image = try saveImage(Self.textImage(nil))
        try index.setFileText("Summer Sale", id: image.id)
        try store.update(id: image.id) { $0.tags = ["ads"] }
        _ = try store.syncNow()
        #expect(try index.fileText(id: image.id) == "Summer Sale")
    }

    @Test func theIndexerReadsEveryWaitingImage() async throws {
        let withText = try saveImage(Self.textImage(nil))
        let withoutText = try saveImage(ClipboardReaderTests.pngData())
        let indexer = ImageTextIndexer()
        indexer.recognize = { url in url.lastPathComponent.hasPrefix(withText.id) ? "hello" : nil }
        indexer.library = store
        await indexer.indexNow()

        #expect(try index.fileText(id: withText.id) == "hello")
        #expect(try index.fileText(id: withoutText.id) == nil)
        #expect(try index.imagesNeedingText().isEmpty)
        #expect(try index.search(SearchQuery.parse("hello")).map(\.id) == [withText.id])
    }

    @Test func imagesWithoutTheirFileAreLeftForLater() async throws {
        let image = try saveImage(Self.textImage(nil))
        try FileManager.default.removeItem(at: store.url(for: image.file!))
        let indexer = ImageTextIndexer()
        indexer.recognize = { _ in "never" }
        indexer.library = store
        await indexer.indexNow()
        #expect(try index.imagesNeedingText().map(\.id) == [image.id])
    }
}
