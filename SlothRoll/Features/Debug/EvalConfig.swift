#if DEBUG
import Foundation

/// Constants for the debug eval screen.
enum EvalConfig {
    /// Photos album holding the hand-picked test screenshots.
    static let albumName = "Sloth Test"

    /// JSON written to the app's Documents folder after every run and every mark.
    static let reportFileName = "eval-report.json"

    /// Launch argument that loads the model and runs the eval with no taps (for device runs).
    static let autorunArgument = "-evalAutorun"

    /// OCR text kept per row in the report, enough to judge the model's answer by eye.
    static let reportTextPreviewCharacters = 400

    static let thumbnailSize = CGSize(width: 54, height: 96)
}
#endif
