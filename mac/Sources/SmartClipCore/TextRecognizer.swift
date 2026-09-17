import Foundation
import ImageIO
import Vision

/// Reads the text in an image with Apple's Vision framework — the same engine
/// behind Live Text. It runs on the Neural Engine, entirely on this Mac: no
/// network, no API key, and a typical screenshot takes well under a second.
public enum TextRecognizer {
    /// Recognised text, one space between lines, capped so a screenshot of a
    /// long document can't bloat the history index (which is kept for ever).
    public static func text(in imageData: Data, maxCharacters: Int = 8_000) -> String {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate      // slower than .fast, but this runs in the background
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            return ""
        }

        // Joined with spaces, not newlines: the history line strips control
        // characters, and "line one\nline two" would become "line oneline two".
        let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
        return String(text.prefix(maxCharacters))
    }
}
