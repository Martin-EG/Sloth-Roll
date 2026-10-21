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
        assetID: String, status: ScanStatus, skipReason: SkipReason? = nil, capturedAt: Date?,
        signals: ImageSignals? = nil
    ) {
        let item = ScreenshotItem(
            assetID: assetID, status: status, skipReason: skipReason, capturedAt: capturedAt)
        if let signals { apply(signals, to: item) }
        context.insert(item)
        save()
    }

    // MARK: Cleanup

    /// Skipped screenshots the cleanup rules may offer for deletion: not camera photos, not
    /// ones the user chose to keep.
    func cleanupEligibleItems() -> [ScreenshotItem] {
        let skipped = ScanStatus.skipped.rawValue
        let descriptor = FetchDescriptor<ScreenshotItem>(
            predicate: #Predicate { $0.statusRaw == skipped },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.skipReason != .camera && $0.cleanupKeptAt == nil }
    }

    /// Items currently offered in the Clean up tab.
    func cleanupCandidateCount() -> Int {
        let descriptor = FetchDescriptor<ScreenshotItem>(
            predicate: #Predicate { $0.cleanupReasonRaw != nil })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func setSignals(_ signals: ImageSignals, on item: ScreenshotItem) {
        apply(signals, to: item)
        save()
    }

    func setCleanupReason(_ reason: CleanupReason?, on item: ScreenshotItem) {
        item.cleanupReason = reason
        item.cleanupCheckedAt = Date()
        save()
    }

    func saveChanges() {
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

    /// Forgets every scanned item except `done` ones, so the next scan reads them again.
    func deleteItemsNotDone() {
        let done = ScanStatus.done.rawValue
        do {
            try context.delete(model: ScreenshotItem.self, where: #Predicate { $0.statusRaw != done })
        } catch {
            Log.storage.error("delete_failed error=\(String(describing: error), privacy: .public)")
        }
        save()
    }

    private func apply(_ signals: ImageSignals, to item: ScreenshotItem) {
        item.sharpness = signals.sharpness
        item.contrast = signals.contrast
        item.featurePrint = signals.featurePrint.map(ImageSignals.data(from:))
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.storage.error("save_failed error=\(String(describing: error), privacy: .public)")
        }
    }
}
