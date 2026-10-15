import Foundation

/// Reads the text inside saved images in the background and puts it in the search index
/// (only there: the Markdown files don't change). Picks up new images after every library
/// change, and older ones the first time it runs.
@MainActor
final class ImageTextIndexer: ObservableObject {
    /// The last image whose text was read, so an open detail pane can show it.
    @Published private(set) var lastIndexedID: String?

    var library: LibraryStore? {
        didSet {
            unavailable = []
            scheduleScan(after: 1)
        }
    }
    /// Replaceable in tests.
    var recognize: @Sendable (URL) -> String? = { ImageTextRecognizer.text(in: $0) }

    static let batchSize = 20

    /// Images whose file isn't there yet (e.g. still in iCloud); tried again on the next launch.
    private var unavailable: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var pass: Task<Void, Never>?
    private var needsAnotherPass = false

    init() {
        NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                // Only this indexer's library (tests create several).
                guard let self, let library = self.library, notification.object as AnyObject === library else { return }
                self.scheduleScan(after: 2)
            }
        }
    }

    /// Reads every image waiting for it, then returns.
    func indexNow() async {
        scanTask?.cancel()
        startPass()
        await pass?.value
    }

    private func scheduleScan(after delay: TimeInterval) {
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.startPass()
        }
    }

    /// One pass at a time; a change during a pass runs another one after it.
    private func startPass() {
        guard pass == nil else {
            needsAnotherPass = true
            return
        }
        pass = Task { [weak self] in
            await self?.runPasses()
        }
    }

    private func runPasses() async {
        repeat {
            needsAnotherPass = false
            await indexWaitingImages()
        } while needsAnotherPass
        pass = nil
    }

    private func indexWaitingImages() async {
        guard let library else { return }
        let index = library.index
        let recognize = self.recognize
        while self.library === library {
            let batch = ((try? index.imagesNeedingText(limit: Self.batchSize + unavailable.count)) ?? [])
                .filter { !unavailable.contains($0.id) }
            guard !batch.isEmpty else { return }

            for reference in batch {
                guard self.library === library, let file = reference.file else { return }
                let url = library.url(for: file)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    unavailable.insert(reference.id)
                    continue
                }
                let text = await Task.detached(priority: .utility) { recognize(url) }.value
                do {
                    // "" marks an image that was read and has no text.
                    try index.setFileText(text ?? "", id: reference.id)
                    lastIndexedID = reference.id
                } catch {
                    unavailable.insert(reference.id)
                }
            }
        }
    }
}
