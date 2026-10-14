import Foundation

/// The small subset of YAML used in Stash front matter: top-level `key: value` pairs whose
/// values are plain, single- or double-quoted scalars, flow lists (`[a, b]`), block lists
/// (`- a` lines, as Obsidian writes them) or literal/folded block scalars (`|`, `>`).
enum FrontMatter {
    enum Value: Equatable {
        case scalar(String)
        case list([String])
        case null
    }

    struct Entry {
        var key: String
        var value: Value
        /// The entry exactly as written, including continuation lines.
        var raw: String
    }

    // MARK: Reading

    static func parse(_ lines: [Substring]) -> [Entry] {
        var entries: [Entry] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            i += 1
            guard let colon = line.firstIndex(of: ":"),
                  !line.hasPrefix(" "), !line.hasPrefix("\t"), !line.hasPrefix("#") else { continue }

            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)

            // Continuation lines: indented, list items, or blank lines inside a block.
            var continuation: [Substring] = []
            while i < lines.count, lines[i].hasPrefix(" ") || lines[i].hasPrefix("\t") || lines[i].hasPrefix("-") || lines[i].isEmpty {
                continuation.append(lines[i])
                i += 1
            }
            while continuation.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                continuation.removeLast()
            }

            let raw = ([line] + continuation).joined(separator: "\n")
            entries.append(Entry(key: key, value: value(of: rest, continuation: continuation), raw: raw))
        }
        return entries
    }

    private static func value(of rest: String, continuation: [Substring]) -> Value {
        if rest.isEmpty {
            let items = continuation
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("-") }
                .map { scalar(String($0.dropFirst()).trimmingCharacters(in: .whitespaces)) ?? "" }
            return items.isEmpty ? .null : .list(items)
        }
        if let indicator = rest.first, indicator == "|" || indicator == ">" {
            return .scalar(blockScalar(continuation, folded: indicator == ">", keepTrailing: rest.hasSuffix("+")))
        }
        if rest.hasPrefix("[") {
            return .list(flowList(rest))
        }
        return scalar(rest).map(Value.scalar) ?? .null
    }

    /// Plain, `'single'` or `"double"` quoted scalar. Nil for null values.
    static func scalar(_ text: String) -> String? {
        if text.hasPrefix("\"") { return doubleQuoted(text.dropFirst()) }
        if text.hasPrefix("'") {
            let body = text.dropFirst()
            let end = body.lastIndex(of: "'") ?? body.endIndex
            return body[..<end].replacingOccurrences(of: "''", with: "'")
        }
        var plain = text
        if let comment = plain.range(of: " #") { plain = String(plain[..<comment.lowerBound]) }
        plain = plain.trimmingCharacters(in: .whitespaces)
        return ["", "~", "null", "Null", "NULL"].contains(plain) ? nil : plain
    }

    private static func doubleQuoted(_ body: Substring) -> String {
        var result = ""
        var iterator = body.makeIterator()
        while let character = iterator.next() {
            switch character {
            case "\"":
                return result
            case "\\":
                guard let escaped = iterator.next() else { return result }
                switch escaped {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "0": result.append("\0")
                case "u", "U":
                    let digits = String((0..<(escaped == "u" ? 4 : 8)).compactMap { _ in iterator.next() })
                    if let code = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(code) {
                        result.unicodeScalars.append(scalar)
                    }
                default: result.append(escaped)
                }
            default:
                result.append(character)
            }
        }
        return result
    }

    /// `[a, "b, c", 'd']` → `["a", "b, c", "d"]`.
    private static func flowList(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var quote: Character?
        for character in text.dropFirst() {
            if let open = quote {
                current.append(character)
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
                current.append(character)
            } else if character == "," || character == "]" {
                if let item = scalar(current.trimmingCharacters(in: .whitespaces)) { items.append(item) }
                current = ""
                if character == "]" { break }
            } else {
                current.append(character)
            }
        }
        return items
    }

    private static func blockScalar(_ lines: [Substring], folded: Bool, keepTrailing: Bool) -> String {
        let indent = lines.compactMap { line -> Int? in
            line.allSatisfy(\.isWhitespace) ? nil : line.prefix(while: { $0 == " " }).count
        }.min() ?? 0
        let body = lines.map { $0.count >= indent ? String($0.dropFirst(indent)) : "" }
        let text = folded ? body.joined(separator: " ") : body.joined(separator: "\n")
        return keepTrailing ? text + "\n" : text
    }

    // MARK: Writing

    /// A scalar written plainly when that's unambiguous, double-quoted otherwise.
    static func quoted(_ value: String, inFlowList: Bool = false) -> String {
        needsQuotes(value, inFlowList: inFlowList) ? doubleQuote(value) : value
    }

    static func flowList(_ items: [String]) -> String {
        "[" + items.map { quoted($0, inFlowList: true) }.joined(separator: ", ") + "]"
    }

    private static func needsQuotes(_ value: String, inFlowList: Bool) -> Bool {
        guard let first = value.first, let last = value.last else { return true }
        if first.isWhitespace || last.isWhitespace { return true }
        if "-?:,[]{}#&*!|>'\"%@`".contains(first) { return true }
        if value.contains(": ") || value.contains(" #") || value.hasSuffix(":") { return true }
        if value.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) { return true }
        if inFlowList, value.contains(where: { ",[]{}".contains($0) }) { return true }
        let lowered = value.lowercased()
        if ["true", "false", "yes", "no", "on", "off", "null", "~"].contains(lowered) { return true }
        // Things other YAML readers (e.g. Obsidian) would read as numbers or dates.
        if Double(value) != nil || value.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func doubleQuote(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            case "\r": result += "\\r"
            default:
                if scalar.properties.generalCategory == .control {
                    result += String(format: "\\u%04X", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }
}
