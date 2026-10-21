import Foundation
import SwiftData

/// One library image the scan has looked at: its status and, once read, the model's result.
/// A rescan skips every asset that already has an item.
@Model
final class ScreenshotItem {
    /// `PHAsset.localIdentifier`.
    @Attribute(.unique) var assetID: String
    /// Raw `ScanStatus`; stored as a string so `#Predicate` can filter on it.
    var statusRaw: String
    var skipReasonRaw: String?
    /// `ActionResult` encoded as JSON.
    var resultData: Data?
    /// When the image was taken, from Photos. Anchors relative dates and sorts the queue.
    var capturedAt: Date?
    /// Last time the pipeline changed this item.
    var processedAt: Date
    /// Laplacian variance of the downscaled grayscale image; low means blurry.
    var sharpness: Double?
    /// Standard deviation of the grayscale pixels; near zero means a flat (blank) image.
    var contrast: Double?
    /// Vision feature print (revision 2) as raw `Float`s, for near-duplicate grouping.
    var featurePrint: Data?
    /// Raw `CleanupReason`; set when the item is offered in the Clean up tab.
    var cleanupReasonRaw: String?
    /// When the cleanup rules or the model last judged this item; nil means not judged yet.
    var cleanupCheckedAt: Date?
    /// When the user left it unselected and deleted the rest; never offered again.
    var cleanupKeptAt: Date?

    init(
        assetID: String, status: ScanStatus, skipReason: SkipReason? = nil,
        capturedAt: Date?, processedAt: Date = Date()
    ) {
        self.assetID = assetID
        self.statusRaw = status.rawValue
        self.skipReasonRaw = skipReason?.rawValue
        self.capturedAt = capturedAt
        self.processedAt = processedAt
    }

    var status: ScanStatus {
        get { ScanStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var skipReason: SkipReason? {
        get { skipReasonRaw.flatMap(SkipReason.init(rawValue:)) }
        set { skipReasonRaw = newValue?.rawValue }
    }

    var cleanupReason: CleanupReason? {
        get { cleanupReasonRaw.flatMap(CleanupReason.init(rawValue:)) }
        set { cleanupReasonRaw = newValue?.rawValue }
    }

    /// Nil until extraction, or if the stored JSON can't be decoded.
    var result: ActionResult? {
        get { resultData.flatMap { try? JSONDecoder().decode(ActionResult.self, from: $0) } }
        set { resultData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
}
