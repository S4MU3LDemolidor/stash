import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Text inside saved files (PDFs, plain text, RTF, Word), so search finds them by content.
/// Runs on-device only and stops after `limit` characters.
enum FileTextExtractor {
    static let limit = 100_000

    static func text(of url: URL, limit: Int = FileTextExtractor.limit) -> String? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        let text: String?
        if type.conforms(to: .pdf) {
            text = pdfText(url, limit: limit)
        } else if type.conforms(to: .plainText) || type.conforms(to: .sourceCode) || type.conforms(to: .commaSeparatedText)
                    || type.conforms(to: .json) {
            text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1))
        } else if type.conforms(to: .rtf) || type.conforms(to: .rtfd) || type.identifier == "org.openxmlformats.wordprocessingml.document" {
            // (HTML import needs WebKit on the main thread, so it isn't supported here.)
            text = try? NSAttributedString(url: url, options: [:], documentAttributes: nil).string
        } else {
            text = nil
        }
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return String(text.prefix(limit))
    }

    private static func pdfText(_ url: URL, limit: Int) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var text = ""
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index)?.string else { continue }
            text += page + "\n"
            if text.count >= limit { break }
        }
        return text
    }
}
