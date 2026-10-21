import CoreGraphics
import Foundation
import Vision

/// Cheap pre-filter before the VLM: on-device OCR (Vision, fast mode). An image is a candidate
/// when it has at least `PipelineConfig.triageMinTextCharacters` characters. No model to load
/// or unload.
struct Triage: ImageTriaging {
    func isCandidate(_ image: CGImage) async -> Bool {
        let scan = await scanText(in: image)
        Log.pipeline.debug(
            "triage chars=\(scan.characterCount) ocr_s=\(scan.duration.seconds, format: .fixed(precision: 3)) candidate=\(scan.hasText)"
        )
        return scan.hasText
    }

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
