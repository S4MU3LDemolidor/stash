import Foundation

/// Fills in a saved link's title, thumbnail and site icon in the background, then updates its
/// file and the index. Links saved while offline, or synced from another Mac without them,
/// are picked up on the next launch or library change.
@MainActor
final class Enricher: ObservableObject {
    /// References waiting for or being fetched; the Library shows a shimmer for them.
    @Published private(set) var inProgress: Set<String> = []

    var library: LibraryStore? {
        didSet { scheduleScan(after: 1) }
    }
    /// Replaceable in tests (no network).
    var fetch: (URL) async -> LinkMetadata? = { url in await MetadataFetcher.shared.metadata(for: url) }

    static let maxConcurrent = 3
    /// A link whose page had no title or image is tried again after this long.
    static let retryInterval: TimeInterval = 7 * 86_400

    private var waiting: [Reference] = []
    private var running = 0
    /// Couldn't be reached this run (e.g. offline); tried again on the next launch.
    private var failedThisRun: Set<String> = []
    private var scanTask: Task<Void, Never>?

    init() {
        NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                // Only this enricher's library (tests create several).
                guard let self, let library = self.library, notification.object as AnyObject === library else { return }
                self.scheduleScan(after: 2)
            }
        }
    }

    /// After saving a link. `prefetched` (from Capture's preview) is used as is, without
    /// another request.
    func enrich(_ reference: Reference, prefetched: LinkMetadata? = nil) {
        guard reference.type == .link, reference.url != nil else { return }
        if let prefetched {
            apply(prefetched, to: reference)
        } else if Preferences.fetchMetadata {
            enqueue(reference)
        }
    }

    // MARK: Queue

    private func enqueue(_ reference: Reference) {
        guard !inProgress.contains(reference.id) else { return }
        inProgress.insert(reference.id)
        waiting.append(reference)
        startNext()
    }

    private func startNext() {
        while running < Self.maxConcurrent, !waiting.isEmpty {
            let reference = waiting.removeFirst()
            running += 1
            Task {
                await process(reference)
                running -= 1
                inProgress.remove(reference.id)
                startNext()
            }
        }
    }

    private func process(_ reference: Reference) async {
        guard let url = reference.url else { return }
        guard let metadata = await fetch(url) else {
            failedThisRun.insert(reference.id)
            return
        }
        apply(metadata, to: reference)
    }

    /// Saves the thumbnail to `assets/<id>.jpg` and the site icon (once per site), then writes the
    /// title and thumbnail into the reference's file. A title it already has (e.g. the browser
    /// tab's) is kept.
    func apply(_ metadata: LinkMetadata, to reference: Reference) {
        guard let library else { return }
        if let site = reference.site, let icon = metadata.icon, library.siteIconURL(for: site) == nil {
            try? library.saveSiteIcon(icon, site: site)
        }

        let thumbnailPath = reference.thumbnail == nil
            ? metadata.thumbnail.flatMap { try? library.saveAsset($0, id: reference.id, fileExtension: "jpg") }
            : nil
        let title = reference.title == nil ? metadata.title : nil

        if title != nil || thumbnailPath != nil {
            do {
                try library.update(id: reference.id) { current in
                    if current.title == nil, let title { current.title = title }
                    if current.thumbnail == nil, let thumbnailPath { current.thumbnail = thumbnailPath }
                }
            } catch {
                // Deleted in the meantime: don't leave its thumbnail behind.
                if let thumbnailPath { try? FileManager.default.removeItem(at: library.url(for: thumbnailPath)) }
                return
            }
        }
        try? library.index.markEnriched(id: reference.id)
    }

    // MARK: Picking up missing metadata

    private func scheduleScan(after delay: TimeInterval) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.scan()
        }
    }

    /// Links without a title or thumbnail that weren't tried recently. Sample data is skipped
    /// so trying out the Library doesn't send hundreds of requests.
    private func scan() {
        guard Preferences.fetchMetadata, let library else { return }
        let cutoff = Date().addingTimeInterval(-Self.retryInterval)
        let candidates = (try? library.index.linksNeedingEnrichment(
            notAttemptedSince: cutoff,
            excludingTag: SampleLibrary.tag
        )) ?? []
        for reference in candidates where !failedThisRun.contains(reference.id) {
            enqueue(reference)
        }
    }
}
