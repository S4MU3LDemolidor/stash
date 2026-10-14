import AppKit
import UniformTypeIdentifiers

/// One opening of Capture: what's about to be saved and what's still loading. Each opening gets
/// a new session, so a save that's still waiting on a browser can't be mixed up with the next one.
@MainActor
final class CaptureSession: ObservableObject {
    @Published var item: CaptureItem? {
        didSet {
            if item?.content != oldValue?.content { preview = Self.preview(for: item?.content) }
        }
    }
    /// Image preview or file icon for the card.
    @Published private(set) var preview: NSImage?
    /// The browser whose tab is being read.
    @Published var readingBrowser: Browser?
    @Published var readingVideoPosition = false
    /// One-line tip shown under the card (permissions, JavaScript setting).
    @Published var hint: String?

    /// The browser read in progress. Saving waits for it.
    var detection: Task<Void, Never>?

    private static func preview(for content: CaptureContent?) -> NSImage? {
        switch content {
        case .image(let data, _):
            return ImageInfo.thumbnail(data: data)
        case .file(let url):
            let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
            return (isImage ? ImageInfo.thumbnail(fileURL: url) : nil) ?? NSWorkspace.shared.icon(forFile: url.path)
        case .link, .text, nil:
            return nil
        }
    }
}
