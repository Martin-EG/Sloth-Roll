#if DEBUG
import CoreGraphics
import Foundation

/// One evaluated screenshot: what OCR and the model found, and the human mark.
struct EvalRow: Identifiable, Sendable {
    let assetID: String
    let thumbnail: CGImage?
    let capturedAt: Date?
    let report: ExtractionReport
    let textScan: TextScan
    var mark: EvalMark?

    var id: String { assetID }

    /// The right type according to the mark, or nil if the row isn't marked yet.
    var expectedType: ActionType? {
        switch mark {
        case .correct: report.result.type
        case .wrong(let expected): expected
        case nil: nil
        }
    }
}
#endif
