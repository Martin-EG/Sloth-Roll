import CoreGraphics
import Foundation

/// One image from the library: full-size for the model and OCR, small for the UI, and where
/// it came from.
struct LibraryImage: Sendable {
    let assetID: String
    let image: CGImage
    let thumbnail: CGImage?
    /// When the screenshot was taken, from Photos. Anchors "hoy" / "tomorrow" in the prompt.
    let capturedAt: Date?
    let source: ImageSource
}
