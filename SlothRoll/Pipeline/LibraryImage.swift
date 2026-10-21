import CoreGraphics

/// One photo from the library: full-size for the model and OCR, small for the UI.
struct LibraryImage: Sendable {
    let assetID: String
    let image: CGImage
    let thumbnail: CGImage?
}
