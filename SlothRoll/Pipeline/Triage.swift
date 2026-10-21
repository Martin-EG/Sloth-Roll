import CoreGraphics
import Foundation
import Vision

/// Cheap pre-filter before the VLM: on-device OCR (Vision, fast mode) to see if a screenshot
/// has any text at all.
struct Triage: Sendable {
    @concurrent
    func scanText(in image: CGImage) async -> TextScan {
        let clock = ContinuousClock()
        let start = clock.now

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        var lines: [String] = []
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
            lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        } catch {
            Log.pipeline.error("ocr_failed error=\(String(describing: error), privacy: .public)")
        }

        let text = lines.joined(separator: "\n")
        return TextScan(
            lineCount: lines.count,
            characterCount: text.filter { !$0.isWhitespace }.count,
            text: text,
            duration: start.duration(to: clock.now))
    }
}
