import Foundation
import ImageIO

/// Where a library image came from: a screenshot, a saved image (a flyer from WhatsApp, an
/// image from Safari), or a camera photo. All three can hold an action (a photo of a flyer);
/// the label is for measuring and tuning triage per kind.
enum ImageSource: String, Codable, Sendable, CaseIterable {
    case screenshot, saved, camera

    /// Screenshot if Photos says so; camera if the file carries camera metadata (TIFF make or
    /// model, or a lens); otherwise saved. Messaging apps strip that metadata when they send
    /// an image, which is what tells a saved flyer apart from a photo taken on a phone.
    init(isScreenshot: Bool, properties: [CFString: Any]?) {
        if isScreenshot {
            self = .screenshot
            return
        }
        let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let cameraKeys = [
            tiff[kCGImagePropertyTIFFMake], tiff[kCGImagePropertyTIFFModel],
            exif[kCGImagePropertyExifLensMake], exif[kCGImagePropertyExifLensModel],
        ]
        let hasCameraMetadata = cameraKeys.contains { value in
            (value as? String).map { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? false
        }
        self = hasCameraMetadata ? .camera : .saved
    }
}
