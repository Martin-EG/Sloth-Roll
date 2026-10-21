import Foundation
import SwiftData

/// The scan's view of SwiftData: what's been seen, what's waiting for the model, and saving
/// each item the moment it changes.
@MainActor
struct ScanStore {
    let context: ModelContext

    /// Every asset with a `ScreenshotItem`, whatever its status.
    func knownAssetIDs() -> Set<String> {
        var descriptor = FetchDescriptor<ScreenshotItem>()
        descriptor.propertiesToFetch = [\.assetID]
        let items = (try? context.fetch(descriptor)) ?? []
        return Set(items.map(\.assetID))
    }

    /// Items that passed triage but haven't been read yet (this scan's and leftovers from a
    /// stopped one), newest first.
    func itemsAwaitingExtraction() -> [ScreenshotItem] {
        let triaged = ScanStatus.triaged.rawValue
        let descriptor = FetchDescriptor<ScreenshotItem>(
            predicate: #Predicate { $0.statusRaw == triaged },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func record(
        assetID: String, status: ScanStatus, skipReason: SkipReason? = nil, capturedAt: Date?
    ) {
        context.insert(
            ScreenshotItem(
                assetID: assetID, status: status, skipReason: skipReason, capturedAt: capturedAt))
        save()
    }

    /// Stores the model's answer: usable actions become `extracted`, "none" `skipped`, and the
    /// fallback `failed`.
    func complete(_ item: ScreenshotItem, with report: ExtractionReport) {
        item.result = report.result
        item.processedAt = Date()
        if report.usedFallback {
            item.status = .failed
        } else if report.result.type == .none {
            item.status = .skipped
            item.skipReason = .noAction
        } else {
            item.status = .extracted
        }
        save()
    }

    /// Debug: forget every scanned item so the next scan starts from zero.
    func deleteAllItems() {
        do {
            try context.delete(model: ScreenshotItem.self)
        } catch {
            Log.storage.error("delete_failed error=\(String(describing: error), privacy: .public)")
        }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.storage.error("save_failed error=\(String(describing: error), privacy: .public)")
        }
    }
}
