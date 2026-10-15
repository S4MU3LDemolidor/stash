import Foundation
import UniformTypeIdentifiers

/// Turns what Capture holds plus the typed note into a saved reference, copying images
/// and files into the library's `assets/`.
@MainActor
struct CaptureSaver {
    let library: LibraryStore

    /// Saves and returns the new reference; nil when there's nothing to save
    /// (no captured item and no note text besides tags).
    func save(_ item: CaptureItem?, note rawNote: String) async throws -> Reference? {
        let note = TagParser.parse(rawNote)

        var reference: Reference
        var assetPath: String?
        switch item?.content {
        case nil:
            // Nothing captured: what was typed is the reference.
            guard !note.text.isEmpty else { return nil }
            return try library.create(Reference(type: .text, tags: note.tags, text: note.text))

        case .link(let url, let title, let timestamp):
            if let videoID = YouTube.videoID(in: url) {
                let position = timestamp ?? YouTube.timestamp(in: url)
                let canonical = YouTube.canonicalURL(videoID: videoID, timestamp: position)
                reference = Reference(
                    type: .link,
                    url: canonical,
                    title: title,
                    // From the canonical URL: youtu.be and m.youtube.com links are youtube.com.
                    site: Reference.site(for: canonical),
                    timestamp: position.flatMap { $0 > 0 ? $0 : nil }
                )
            } else {
                reference = Reference(type: .link, url: url, title: title, site: Reference.site(for: url))
            }

        case .text(let text):
            reference = Reference(type: .text, text: text)

        case .image(let data, let fileExtension):
            reference = Reference(type: .image)
            assetPath = try library.saveAsset(data, id: reference.id, fileExtension: fileExtension)
            reference.file = assetPath
            if let size = ImageInfo.pixelSize(data: data) {
                (reference.width, reference.height) = size
            }

        case .file(let source):
            let isImage = UTType(filenameExtension: source.pathExtension)?.conforms(to: .image) ?? false
            reference = Reference(type: isImage ? .image : .file, originalFilename: source.lastPathComponent)
            let path = library.assetPath(id: reference.id, fileExtension: source.pathExtension)
            let destination = library.url(for: path)
            // Files can be large (videos): copy off the main thread.
            try await Task.detached(priority: .userInitiated) {
                try FileManager.default.copyItem(at: source, to: destination)
            }.value
            assetPath = path
            reference.file = path
            if isImage, let size = ImageInfo.pixelSize(fileURL: destination) {
                (reference.width, reference.height) = size
            }
        }

        reference.tags = note.tags
        reference.note = note.text
        do {
            return try library.create(reference)
        } catch {
            // Don't leave an orphaned asset behind.
            if let assetPath { try? FileManager.default.removeItem(at: library.url(for: assetPath)) }
            throw error
        }
    }

    enum MergeResult: Equatable {
        case merged(Reference)
        /// The reference already had all of it; nothing was written.
        case unchanged(Reference)
    }

    /// Adds what's new in this capture to a reference that already holds the same thing:
    /// tags it doesn't have, the note on a new paragraph (unless it's already there), and a
    /// link's title if it had none.
    func merge(_ item: CaptureItem?, note rawNote: String, into existing: Reference) throws -> MergeResult {
        let note = TagParser.parse(rawNote)
        var title: String?
        if case .link(_, let captured, _)? = item?.content { title = captured }

        let addsTags = note.tags.contains { !existing.tags.contains($0) }
        let addsNote = !note.text.isEmpty && !existing.note.contains(note.text)
        let addsTitle = existing.type == .link && existing.title == nil && title != nil
        guard addsTags || addsNote || addsTitle else { return .unchanged(existing) }

        let merged = try library.update(id: existing.id) { reference in
            for tag in note.tags where !reference.tags.contains(tag) {
                reference.tags.append(tag)
            }
            if !note.text.isEmpty, !reference.note.contains(note.text) {
                reference.note = reference.note.isEmpty ? note.text : reference.note + "\n\n" + note.text
            }
            if reference.type == .link, reference.title == nil, let title {
                reference.title = title
            }
        }
        return .merged(merged)
    }
}
