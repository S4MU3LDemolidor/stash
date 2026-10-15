import AppKit
import QuickLookThumbnailing

/// Quick Look previews of shelf items (real thumbnails for images, PDFs and videos; icons for the
/// rest), made once per item and kept while it's on the shelf.
@MainActor
final class ShelfThumbnails: ObservableObject {
    @Published private(set) var images: [UUID: NSImage] = [:]
    private var pending: Set<UUID> = []

    func load(_ item: ShelfItem, url: URL?) {
        guard images[item.id] == nil, !pending.contains(item.id), let url else { return }
        pending.insert(item.id)
        let size = CGSize(width: Metrics.shelfThumb * 2, height: Metrics.shelfThumb * 2)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2, representationTypes: .all)
        let id = item.id
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            let box = ThumbnailBox(image: representation?.nsImage ?? NSWorkspace.shared.icon(forFile: url.path))
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.pending.remove(id)
                    self?.images[id] = box.image
                }
            }
        }
    }

    /// Drops previews of items that left the shelf.
    func keep(only ids: Set<UUID>) {
        images = images.filter { ids.contains($0.key) }
        pending = pending.intersection(ids)
    }
}

/// Carries an image made off the main thread back to it.
private struct ThumbnailBox: @unchecked Sendable {
    let image: NSImage
}
