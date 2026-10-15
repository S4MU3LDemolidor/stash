import Foundation

/// When two captures are the same thing, however they were shared: the same page without
/// tracking parameters, the same moment of a video, the same text give or take spacing and case.
/// (Images and files are compared by content, in `DuplicateFinder`.)
enum DuplicateKey {
    /// Query parameters that only say where a link was shared from.
    static let trackingParameters: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "yclid", "igshid", "si", "ref", "ref_src", "ref_url",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok", "spm", "share", "feature",
    ]

    /// Two saves of a video less than this many seconds apart are the same moment.
    static let timestampTolerance = 2

    static func isTracking(_ parameter: String) -> Bool {
        let name = parameter.lowercased()
        return name.hasPrefix("utm_") || trackingParameters.contains(name)
    }

    /// `https://www.example.com/a/?utm_source=x&b=2&a=1#top` → `example.com/a?a=1&b=2`.
    /// YouTube videos → `youtube:ID` (compare their timestamps with `sameMoment`).
    static func link(_ url: URL) -> String {
        if let videoID = YouTube.videoID(in: url) { return "youtube:" + videoID }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }

        var key = ""
        if let scheme = components.scheme?.lowercased(), scheme != "http", scheme != "https" {
            key += scheme + "://"
        }
        key += Reference.site(for: url) ?? ""
        if let port = components.port { key += ":\(port)" }

        var path = components.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        key += path

        let items = (components.percentEncodedQueryItems ?? [])
            .filter { !isTracking($0.name) }
            .map { item in item.value.map { "\(item.name)=\($0)" } ?? item.name }
            .sorted()
        if !items.isEmpty { key += "?" + items.joined(separator: "&") }

        // Fragments are usually a spot on the page, except in apps that route with them (#/inbox).
        if let fragment = components.percentEncodedFragment, fragment.hasPrefix("/") || fragment.hasPrefix("!") {
            key += "#" + fragment
        }
        return key
    }

    /// Playback positions that count as the same moment (no position is the start).
    static func sameMoment(_ a: Int?, _ b: Int?) -> Bool {
        abs((a ?? 0) - (b ?? 0)) <= timestampTolerance
    }

    /// Whether a link with `position` (YouTube only) is already saved as `reference`.
    static func link(_ url: URL, position: Int?, matches reference: Reference) -> Bool {
        guard reference.type == .link, let saved = reference.url, link(saved) == link(url) else { return false }
        guard YouTube.videoID(in: url) != nil else { return true }
        return sameMoment(position, reference.timestamp ?? YouTube.timestamp(in: saved))
    }

    /// `"  Hello\n  World "` → `"hello world"`.
    static func text(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }
}
