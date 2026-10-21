import CoreGraphics
import Foundation

/// Decides which skipped screenshots go to the Clean up tab: blurry ones and older
/// near-duplicates by rule, the rest by asking the extraction model "still useful?".
@MainActor
struct CleanupJudge {
    private let vlm: any VLMServing
    private let store: ScanStore
    private let finder: DuplicateFinder

    init(vlm: any VLMServing, store: ScanStore, finder: DuplicateFinder = DuplicateFinder()) {
        self.vlm = vlm
        self.store = store
        self.finder = finder
    }

    /// Eligible items not measured yet (skipped before this feature, or analysis failed).
    func itemsMissingSignals() -> [ScreenshotItem] {
        store.cleanupEligibleItems().filter { $0.sharpness == nil }
    }

    /// Marks older near-duplicates and blurry screenshots. Re-run every scan: a new screenshot
    /// can make an older one a duplicate, and a deleted twin frees one to be judged alone.
    func applyRules() async {
        let pool = store.cleanupEligibleItems().filter { $0.sharpness != nil }
        let entries = pool.compactMap { item in
            item.featurePrint.map {
                DuplicateFinder.Entry(
                    id: item.assetID, capturedAt: item.capturedAt,
                    featurePrint: ImageSignals.featurePrint(from: $0))
            }
        }
        let duplicates = await finder.findOlderDuplicates(in: entries)
        let now = Date()
        for item in pool {
            if duplicates.contains(item.assetID) {
                if item.cleanupReason != .duplicate {
                    item.cleanupReason = .duplicate
                    item.cleanupCheckedAt = now
                }
                continue
            }
            if item.cleanupReason == .duplicate {
                // Its newer twin is gone: judge it again on its own.
                item.cleanupReason = nil
                item.cleanupCheckedAt = nil
            }
            if item.cleanupCheckedAt == nil, let sharpness = item.sharpness,
                ImageSignals.isBlurry(sharpness: sharpness, contrast: item.contrast ?? 0)
            {
                item.cleanupReason = .blurry
                item.cleanupCheckedAt = now
            }
        }
        store.saveChanges()
        Log.pipeline.info("cleanup_rules pool=\(pool.count) duplicates=\(duplicates.count)")
    }

    /// Measured, not blurry, not a duplicate, and not judged yet: the model decides these.
    func itemsToAsk() -> [ScreenshotItem] {
        store.cleanupEligibleItems().filter { $0.sharpness != nil && $0.cleanupCheckedAt == nil }
    }

    /// Asks the loaded model about one screenshot. Only a clear "no" offers it for deletion;
    /// a failed generation leaves it unjudged so the next scan asks again.
    func ask(about item: ScreenshotItem, image: CGImage) async {
        let answer: String
        do {
            answer = try await vlm.describe(image: image, prompt: UsefulnessQuestion.prompt)
        } catch {
            Log.pipeline.error("cleanup_ask_failed error=\(String(describing: error), privacy: .public)")
            return
        }
        let useful = UsefulnessQuestion.parse(answer)
        Log.pipeline.info("cleanup_ask useful=\(String(describing: useful), privacy: .public)")
        store.setCleanupReason(useful == false ? .notUseful : nil, on: item)
    }

    func candidateCount() -> Int {
        store.cleanupCandidateCount()
    }
}
