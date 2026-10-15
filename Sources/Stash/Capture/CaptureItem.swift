import AppKit

/// What Capture is about to save.
enum CaptureContent: Equatable {
    case link(URL, title: String?, timestamp: Int?)
    case text(String)
    /// Image data (e.g. from the clipboard) and the file extension to save it under.
    case image(Data, fileExtension: String)
    /// A file on disk, copied into the library on save. Image files become image references.
    case file(URL)

    /// Copying an image or a file is a deliberate act, so it beats the browser tab.
    var isImageOrFile: Bool {
        switch self {
        case .image, .file: true
        case .link, .text: false
        }
    }
}

/// Where the captured content came from, shown as the card's badge.
enum CaptureOrigin: Equatable {
    case browser(String)
    case clipboard
    case pasted
    case dropped

    var badge: String {
        switch self {
        case .browser(let name): String(localized: "From \(name)")
        case .clipboard: String(localized: "From Clipboard")
        case .pasted: String(localized: "Pasted")
        case .dropped: String(localized: "Dropped")
        }
    }
}

struct CaptureItem: Equatable {
    var content: CaptureContent
    var origin: CaptureOrigin
}

/// Tab titles as browsers report them → titles worth saving.
enum CaptureTitle {
    /// `"(3) How I Write Hooks - YouTube"` → `"How I Write Hooks"`.
    static func clean(_ title: String?, for url: URL) -> String? {
        guard var title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
        if YouTube.videoID(in: url) != nil {
            // Unread-notification count prefix and the site suffix.
            if let range = title.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) {
                title.removeSubrange(range)
            }
            if title.hasSuffix(" - YouTube") {
                title.removeLast(" - YouTube".count)
            }
        }
        // Pages without a <title> report their URL.
        if title == url.absoluteString || title == url.host(percentEncoded: false) { return nil }
        return title.isEmpty ? nil : title
    }
}
