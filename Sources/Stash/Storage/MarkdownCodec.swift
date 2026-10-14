import Foundation

/// Converts a `Reference` to and from its Markdown file: YAML front matter between `---`
/// lines, then the body (the note, or the saved text for text references).
enum MarkdownCodec {
    enum DecodeError: Error, Equatable {
        case missingFrontMatter
        case missingField(String)
        case invalidField(String)
    }

    private static let knownKeys: Set<String> = [
        "id", "type", "url", "title", "site", "timestamp", "file", "filename",
        "width", "height", "tags", "thumbnail", "note", "created",
    ]

    // MARK: Encode

    static func encode(_ reference: Reference, timeZone: TimeZone = .current) -> String {
        var lines = ["---", "id: \(reference.id)", "type: \(reference.type.rawValue)"]

        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            lines.append("\(key): \(FrontMatter.quoted(value))")
        }
        func add(_ key: String, _ number: Int?) {
            guard let number else { return }
            lines.append("\(key): \(number)")
        }

        add("url", reference.url?.absoluteString)
        add("title", reference.title)
        add("site", reference.site)
        add("timestamp", reference.timestamp)
        add("file", reference.file)
        add("filename", reference.originalFilename)
        add("width", reference.width)
        add("height", reference.height)
        lines.append("tags: \(FrontMatter.flowList(reference.tags))")
        add("thumbnail", reference.thumbnail)
        if reference.type == .text {
            add("note", reference.note)
        }
        lines.append("created: \(dateString(reference.created, timeZone: timeZone))")
        lines += reference.extraFields.map(\.raw)
        lines.append("---")

        let body = reference.type == .text ? (reference.text ?? "") : reference.note
        if !body.isEmpty {
            lines.append(body)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Decode

    /// - Parameter fallbackCreated: used when the file has no valid `created` (e.g. written by hand).
    static func decode(_ markdown: String, fallbackCreated: Date? = nil) throws -> Reference {
        let (frontMatter, body) = try split(markdown)
        let entries = FrontMatter.parse(frontMatter)

        var values: [String: FrontMatter.Value] = [:]
        var extras: [FrontMatterEntry] = []
        for entry in entries {
            if knownKeys.contains(entry.key) {
                values[entry.key] = entry.value
            } else {
                extras.append(FrontMatterEntry(key: entry.key, raw: entry.raw))
            }
        }

        func string(_ key: String) -> String? {
            guard case .scalar(let value)? = values[key] else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func int(_ key: String) -> Int? { string(key).flatMap { Int($0) } }

        guard let id = string("id") else { throw DecodeError.missingField("id") }
        guard let created = string("created").flatMap(parseDate) ?? fallbackCreated else {
            throw DecodeError.missingField("created")
        }

        let url = string("url").flatMap { URL(string: $0) }
        let file = string("file")
        let type: ReferenceType
        if let rawType = string("type") {
            guard let parsed = ReferenceType(rawValue: rawType.lowercased()) else {
                throw DecodeError.invalidField("type")
            }
            type = parsed
        } else {
            type = url != nil ? .link : file != nil ? .file : .text
        }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        var reference = Reference(
            id: id,
            type: type,
            created: created,
            url: url,
            title: string("title"),
            site: string("site"),
            timestamp: int("timestamp"),
            file: file,
            originalFilename: string("filename"),
            width: int("width"),
            height: int("height"),
            thumbnail: string("thumbnail"),
            tags: tags(values["tags"]),
            note: type == .text ? (string("note") ?? "") : trimmedBody,
            text: type == .text ? trimmedBody : nil
        )
        reference.extraFields = extras
        return reference
    }

    /// Accepts a list (`[a, b]` or `- a` lines) or a single string (`a, b` / `a b`).
    private static func tags(_ value: FrontMatter.Value?) -> [String] {
        let raw: [String]
        switch value {
        case .list(let items): raw = items
        case .scalar(let text): raw = text.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
        case .null, nil: raw = []
        }
        var tags: [String] = []
        for tag in raw.compactMap(TagParser.normalize) where !tags.contains(tag) {
            tags.append(tag)
        }
        return tags
    }

    private static func split(_ markdown: String) throws -> (frontMatter: [Substring], body: Substring) {
        var text = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let close = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else { throw DecodeError.missingFrontMatter }

        let body = lines[(close + 1)...].joined(separator: "\n")
        return (Array(lines[1..<close]), Substring(body))
    }

    // MARK: Dates

    static func dateString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime],
            [.withInternetDateTime, .withFractionalSeconds],
            [.withFullDate],
        ] {
            formatter.formatOptions = options
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
