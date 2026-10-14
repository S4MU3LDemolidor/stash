import AppKit
import SwiftUI

/// Downsampled previews of images in the library, made off the main thread and kept in memory.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 500
    }

    func cached(_ url: URL, maxPixels: Int) -> NSImage? {
        cache.object(forKey: key(url, maxPixels))
    }

    func load(_ url: URL, maxPixels: Int) async -> NSImage? {
        if let image = cached(url, maxPixels: maxPixels) { return image }
        let box = await Task.detached(priority: .userInitiated) {
            ImageBox(image: ImageInfo.thumbnail(fileURL: url, maxPixels: maxPixels))
        }.value
        if let image = box.image { cache.setObject(image, forKey: key(url, maxPixels)) }
        return box.image
    }

    private func key(_ url: URL, _ maxPixels: Int) -> NSString {
        "\(maxPixels)|\(url.path)" as NSString
    }
}

/// Carries a freshly made, not yet shared image out of a background task.
private struct ImageBox: @unchecked Sendable {
    let image: NSImage?
}

/// An image from the library, loaded in the background; fades in when ready (design.md §7).
struct AssetImage<Placeholder: View>: View {
    let url: URL?
    let maxPixels: Int
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: NSImage?

    init(url: URL?, maxPixels: Int, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxPixels = maxPixels
        self.contentMode = contentMode
        self.placeholder = placeholder
        _image = State(initialValue: url.flatMap { ThumbnailCache.shared.cached($0, maxPixels: maxPixels) })
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if image != nil, ThumbnailCache.shared.cached(url, maxPixels: maxPixels) === image { return }
            let loaded = await ThumbnailCache.shared.load(url, maxPixels: maxPixels)
            withAnimation(.easeIn(duration: Motion.thumbnailFade)) { image = loaded }
        }
    }
}
