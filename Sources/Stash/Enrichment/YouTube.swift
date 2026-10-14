import Foundation

/// YouTube URL handling. Every form of video URL (`youtu.be`, `/shorts/`, `m.youtube.com`,
/// `/embed/`, `/live/`) becomes `https://www.youtube.com/watch?v=ID&t=SECONDSs`.
enum YouTube {
    private static let hosts: Set<String> = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com",
        "youtube-nocookie.com", "www.youtube-nocookie.com",
    ]
    private static let pathPrefixes = ["/shorts/", "/embed/", "/live/", "/v/"]

    /// The 11-character video ID, if `url` points to a YouTube video.
    static func videoID(in url: URL) -> String? {
        guard let host = url.host(percentEncoded: false)?.lowercased() else { return nil }
        let path = url.path(percentEncoded: false)

        let candidate: String?
        if host == "youtu.be" {
            candidate = path.split(separator: "/").first.map(String.init)
        } else if hosts.contains(host) {
            if path == "/watch" || path == "/watch/" {
                candidate = queryValue("v", in: url)
            } else if let prefix = pathPrefixes.first(where: path.hasPrefix) {
                candidate = path.dropFirst(prefix.count).split(separator: "/").first.map(String.init)
            } else {
                candidate = nil
            }
        } else {
            candidate = nil
        }

        guard let id = candidate, isValidID(id) else { return nil }
        return id
    }

    /// The playback position in the URL (`t=` or `start=`), in seconds.
    static func timestamp(in url: URL) -> Int? {
        let value = queryValue("t", in: url) ?? queryValue("start", in: url)
            // youtu.be links sometimes carry it in the fragment: #t=1m2s
            ?? url.fragment(percentEncoded: false).flatMap { $0.hasPrefix("t=") ? String($0.dropFirst(2)) : nil }
        return value.flatMap(parseTime)
    }

    /// `https://www.youtube.com/watch?v=ID` plus `&t=SECONDSs` when there's a position.
    static func canonicalURL(videoID: String, timestamp: Int?) -> URL {
        var components = URLComponents(string: "https://www.youtube.com/watch")!
        var items = [URLQueryItem(name: "v", value: videoID)]
        if let timestamp, timestamp > 0 {
            items.append(URLQueryItem(name: "t", value: "\(timestamp)s"))
        }
        components.queryItems = items
        return components.url!
    }

    /// Canonical form of a YouTube video URL, or nil if `url` isn't one. `timestamp`
    /// (e.g. read from the playing video) wins over any position already in the URL.
    static func normalize(_ url: URL, timestamp: Int? = nil) -> URL? {
        guard let id = videoID(in: url) else { return nil }
        return canonicalURL(videoID: id, timestamp: timestamp ?? self.timestamp(in: url))
    }

    /// `"272"`, `"272s"`, `"4m32s"`, `"1h2m3s"` → seconds.
    static func parseTime(_ text: String) -> Int? {
        let value = text.lowercased()
        if let seconds = Int(value) { return seconds >= 0 ? seconds : nil }

        var total = 0
        var number = ""
        var sawUnit = false
        for character in value {
            if character.isNumber {
                number.append(character)
            } else {
                guard let amount = Int(number) else { return nil }
                switch character {
                case "h": total += amount * 3600
                case "m": total += amount * 60
                case "s": total += amount
                default: return nil
                }
                number = ""
                sawUnit = true
            }
        }
        return sawUnit && number.isEmpty ? total : nil
    }

    /// `272` → `"4:32"`, `3723` → `"1:02:03"`.
    static func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }

    private static func isValidID(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}
