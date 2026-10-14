import AppKit
import UniformTypeIdentifiers

/// One opening of Capture: what's about to be saved and what's still loading. Each opening gets
/// a new session, so a save that's still waiting on a browser can't be mixed up with the next one.
@MainActor
final class CaptureSession: ObservableObject {
    @Published var item: CaptureItem? {
        didSet {
            if item?.content != oldValue?.content { preview = Self.preview(for: item?.content) }
            if Self.linkURL(item) != Self.linkURL(oldValue) { fetchMetadata(for: Self.linkURL(item)) }
        }
    }
    /// Image preview or file icon for the card.
    @Published private(set) var preview: NSImage?
    /// A link's page image, once fetched.
    @Published private(set) var linkThumbnail: NSImage?
    @Published private(set) var fetchingMetadata = false
    /// What was fetched for the link, handed to the Enricher on save so it isn't fetched twice.
    private(set) var metadata: LinkMetadata?
    private var metadataTask: Task<Void, Never>?
    /// The browser whose tab is being read.
    @Published var readingBrowser: Browser?
    @Published var readingVideoPosition = false
    /// One-line tip shown under the card (permissions, JavaScript setting).
    @Published var hint: String?

    /// The browser read in progress. Saving waits for it.
    var detection: Task<Void, Never>?

    private static func linkURL(_ item: CaptureItem?) -> URL? {
        if case .link(let url, _, _)? = item?.content { return url }
        return nil
    }

    /// Starts fetching the title and thumbnail as soon as there's a link to show
    /// (design.md §4: the URL first, a shimmer, then the title).
    private func fetchMetadata(for url: URL?) {
        metadataTask?.cancel()
        metadata = nil
        linkThumbnail = nil
        fetchingMetadata = false
        guard let url, Preferences.fetchMetadata else { return }

        fetchingMetadata = true
        metadataTask = Task { [weak self] in
            let metadata = await MetadataFetcher.shared.metadata(for: url)
            guard let self, !Task.isCancelled else { return }
            self.fetchingMetadata = false
            self.metadata = metadata
            self.linkThumbnail = metadata?.thumbnail.flatMap(ImageInfo.thumbnail(data:))
            // A pasted link has no title yet: fill it in (a browser tab's title is kept).
            if case .link(url, nil, let timestamp)? = self.item?.content, let title = metadata?.title {
                self.item?.content = .link(url, title: title, timestamp: timestamp)
            }
        }
    }

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
