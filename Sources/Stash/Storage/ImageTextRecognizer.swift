import Foundation
import Vision

/// Text inside saved images (screenshots, ad creatives), so search finds them by what they say.
/// Runs on-device with Vision, never over the network. Slow-ish (up to a second for a large
/// screenshot): call it off the main thread.
enum ImageTextRecognizer {
    static func text(in url: URL, limit: Int = FileTextExtractor.limit) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(url: url, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(limit))
    }
}
