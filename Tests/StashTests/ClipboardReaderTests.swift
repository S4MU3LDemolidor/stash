import AppKit
import Testing
@testable import Stash

/// Uses a private pasteboard, never the user's clipboard.
@MainActor
@Suite("Clipboard and drop reading")
final class ClipboardReaderTests {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("dev.stash.tests.\(UUID().uuidString)"))

    init() {
        pasteboard.clearContents()
    }

    deinit {
        pasteboard.releaseGlobally()
    }

    nonisolated static func pngData(width: Int = 3, height: Int = 2) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
    }

    private var content: CaptureContent? { ClipboardReader.content(of: pasteboard) }

    @Test func pngStaysPNG() {
        let png = Self.pngData()
        pasteboard.setData(png, forType: .png)
        #expect(content == .image(png, fileExtension: "png"))
    }

    @Test func tiffBecomesPNG() throws {
        let tiff = try #require(NSBitmapImageRep(data: Self.pngData())?.tiffRepresentation)
        pasteboard.setData(tiff, forType: .tiff)
        guard case .image(let data, let fileExtension)? = content else {
            Issue.record("Expected an image, got \(String(describing: content))")
            return
        }
        #expect(fileExtension == "png")
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func aURLBecomesALink() {
        pasteboard.setString("  https://example.com/article?id=1 \n", forType: .string)
        #expect(content == .link(URL(string: "https://example.com/article?id=1")!, title: nil, timestamp: nil))
    }

    @Test func otherTextIsText() {
        pasteboard.setString("Stop selling. Start telling.", forType: .string)
        #expect(content == .text("Stop selling. Start telling."))
    }

    @Test func browserCopyImageIsTheImage() {
        // "Copy Image" in a browser: the image plus, at most, its URL.
        let png = Self.pngData()
        pasteboard.declareTypes([.png, .string], owner: nil)
        pasteboard.setData(png, forType: .png)
        pasteboard.setString("https://example.com/ad.png", forType: .string)
        #expect(content == .image(png, fileExtension: "png"))
    }

    @Test func spreadsheetCellsAreText() {
        // Spreadsheets copy cells as text plus a picture of them.
        pasteboard.declareTypes([.png, .string], owner: nil)
        pasteboard.setData(Self.pngData(), forType: .png)
        pasteboard.setString("Q4 budget\t1200", forType: .string)
        #expect(content == .text("Q4 budget\t1200"))
    }

    @Test func copiedFilesAreFiles() {
        let file = URL(fileURLWithPath: "/tmp/brief.pdf")
        pasteboard.writeObjects([file as NSURL])
        #expect(content == .file(file))
    }

    @Test func foldersAreIgnored() {
        pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/", isDirectory: true) as NSURL])
        #expect(content == nil)
    }

    @Test func passwordManagerSecretsAreNeverCaptured() {
        pasteboard.declareTypes([.string, .init("org.nspasteboard.ConcealedType")], owner: nil)
        pasteboard.setString("hunter2", forType: .string)
        #expect(content == nil)
    }

    @Test func emptyClipboard() {
        #expect(content == nil)
    }

    @Test func webURLs() {
        #expect(ClipboardReader.webURL("https://example.com") != nil)
        #expect(ClipboardReader.webURL("http://example.com/a b") == nil)
        #expect(ClipboardReader.webURL("ftp://example.com") == nil)
        #expect(ClipboardReader.webURL("https://") == nil)
        #expect(ClipboardReader.webURL("example.com") == nil)
    }
}
