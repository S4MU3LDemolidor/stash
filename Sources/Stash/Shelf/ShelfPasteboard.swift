import AppKit
import UniformTypeIdentifiers

/// Turns drops into shelf items, and shelf items back into drag data.
@MainActor
enum ShelfPasteboard {
    /// The page title some browsers attach to a dragged link.
    static let urlName = NSPasteboard.PasteboardType("public.url-name")

    /// Types the shelf and the menu bar icon register for.
    static var acceptedTypes: [NSPasteboard.PasteboardType] {
        ClipboardReader.acceptedTypes + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    }

    /// The items a drop adds right away. Promised files (Photos, Mail) arrive later; see `promises(in:)`.
    static func items(from pasteboard: NSPasteboard, store: ShelfStore) throws -> [ShelfItem] {
        let types = Set(pasteboard.types ?? [])
        guard types.isDisjoint(with: ClipboardReader.privateTypes) else { return [] }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            return try urls.map { try ShelfItem.file(at: $0) }
        }
        switch ClipboardReader.content(of: pasteboard) {
        case .image(let data, let fileExtension)?:
            let name = try store.storeCopy(data, fileExtension: fileExtension)
            return [ShelfItem(name: String(localized: "Image"), kind: .stored(fileName: name, type: .image))]
        case .text(let text)?:
            let name = try store.storeCopy(Data(text.utf8), fileExtension: "txt")
            return [ShelfItem(name: ShelfItem.preview(of: text), kind: .stored(fileName: name, type: .text))]
        case .link(let url, _, _)?:
            let raw = pasteboard.string(forType: urlName)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = raw?.isEmpty == false ? raw : nil
            let name = title ?? url.host(percentEncoded: false) ?? url.absoluteString
            return [ShelfItem(name: name, kind: .link(url, title: title))]
        case .file(let url)?:
            return [try ShelfItem.file(at: url)]
        case nil:
            return []
        }
    }

    /// File promises in a drop (Photos, Mail attachments, some browsers' images).
    static func promises(in pasteboard: NSPasteboard) -> [NSFilePromiseReceiver] {
        pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
    }

    /// Drag data for items going back out. Missing originals are left out.
    static func writers(for items: [ShelfItem], store: ShelfStore) -> [NSPasteboardWriting] {
        items.compactMap { item -> NSPasteboardWriting? in
            switch item.kind {
            case .link(let url, let title):
                let entry = NSPasteboardItem()
                entry.setString(url.absoluteString, forType: .URL)
                entry.setString(url.absoluteString, forType: .string)
                if let title { entry.setString(title, forType: urlName) }
                return entry
            case .stored(_, let type):
                guard let url = store.fileURL(for: item) else { return nil }
                let entry = NSPasteboardItem()
                entry.setString(url.absoluteString, forType: .fileURL)
                if type == .text, let text = try? String(contentsOf: url, encoding: .utf8) {
                    entry.setString(text, forType: .string)
                }
                if type == .image, let data = try? Data(contentsOf: url),
                   let uti = UTType(filenameExtension: url.pathExtension) {
                    entry.setData(data, forType: NSPasteboard.PasteboardType(uti.identifier))
                }
                return entry
            case .file:
                return store.fileURL(for: item).map { $0 as NSURL }
            }
        }
    }
}
