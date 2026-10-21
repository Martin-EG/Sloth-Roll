import Foundation

/// What on-device OCR found in one screenshot, and how long it took.
struct TextScan: Sendable, Equatable {
    let lineCount: Int
    let characterCount: Int
    /// Recognized text, lines joined with newlines.
    let text: String
    let duration: Duration

    /// Enough text to pass triage.
    var hasText: Bool { characterCount >= PipelineConfig.triageMinTextCharacters }
}
