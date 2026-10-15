import CryptoKit
import Foundation

/// Looks in the library for a reference that already holds what Capture is about to save.
/// When several do, the newest wins.
@MainActor
struct DuplicateFinder {
    let library: LibraryStore

    func existing(for content: CaptureContent) async -> Reference? {
        switch content {
        case .link(let url, _, let timestamp):
            let videoID = YouTube.videoID(in: url)
            let position = videoID != nil ? (timestamp ?? YouTube.timestamp(in: url)) : nil
            // Narrow down in SQL (same video or same host), then compare properly.
            guard let needle = videoID ?? Reference.site(for: url) else { return nil }
            let candidates = (try? library.index.links(urlContaining: needle)) ?? []
            return candidates.first { DuplicateKey.link(url, position: position, matches: $0) }

        case .text(let text):
            let key = DuplicateKey.text(text)
            guard !key.isEmpty else { return nil }
            let candidates = (try? library.index.references(ofTypes: [.text])) ?? []
            return candidates.first { $0.text.map(DuplicateKey.text) == key }

        case .image(let data, _):
            return await sameContent(as: .data(data))

        case .file(let url):
            return await sameContent(as: .file(url))
        }
    }

    // MARK: Images and files

    private enum Content: Sendable {
        case data(Data)
        case file(URL)
    }

    /// Images and files with the same bytes. Only those with the same size are hashed.
    private func sameContent(as content: Content) async -> Reference? {
        let candidates = ((try? library.index.references(ofTypes: [.image, .file])) ?? [])
            .compactMap { reference in reference.file.map { (reference, library.url(for: $0)) } }
        guard !candidates.isEmpty else { return nil }

        let matchIndex = await Task.detached(priority: .userInitiated) { () -> Int? in
            let size: Int
            switch content {
            case .data(let data): size = data.count
            case .file(let url):
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                      values.isDirectory != true, let fileSize = values.fileSize else { return nil }
                size = fileSize
            }

            var digest: SHA256Digest?
            for (offset, candidate) in candidates.enumerated() {
                guard Self.size(of: candidate.1) == size else { continue }
                if digest == nil {
                    switch content {
                    case .data(let data): digest = SHA256.hash(data: data)
                    case .file(let url): digest = Self.sha256(of: url)
                    }
                    if digest == nil { return nil }
                }
                if Self.sha256(of: candidate.1) == digest { return offset }
            }
            return nil
        }.value
        return matchIndex.map { candidates[$0].0 }
    }

    private nonisolated static func size(of url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    /// Read in 1 MB pieces, so a large video doesn't have to fit in memory.
    nonisolated static func sha256(of url: URL) -> SHA256Digest? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize()
    }
}
