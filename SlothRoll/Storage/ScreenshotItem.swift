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

    /// Nil until extraction, or if the stored JSON can't be decoded.
    var result: ActionResult? {
        get { resultData.flatMap { try? JSONDecoder().decode(ActionResult.self, from: $0) } }
        set { resultData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
}
