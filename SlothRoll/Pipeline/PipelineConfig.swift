import Foundation

/// Tunables for the scan pipeline (prompting, retries, parsing, triage).
enum PipelineConfig {
    /// First try plus one stricter retry.
    static let maxExtractionAttempts = 2

    /// Title of the safe result returned when the model's answer can't be used.
    static let fallbackTitle = "Couldn't read this one"

    /// Days after today listed in the prompt so a small model can look up relative dates.
    static let promptCalendarDays = 7

    /// Recognized characters at or above this count mean "this screenshot has text".
    static let triageMinTextCharacters = 1

    /// Longest side, in pixels, of thumbnails decoded from the photo library.
    static let thumbnailMaxPixels = 240
}
