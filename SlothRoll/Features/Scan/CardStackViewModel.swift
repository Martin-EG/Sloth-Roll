import CoreGraphics
import Foundation
import Observation
import SwiftData

/// Drives the review cards: runs the action on a right swipe, skips on a left swipe, saves
/// edits, and loads card images.
@Observable
@MainActor
final class CardStackViewModel {
    /// Outcome or error of the last swipe, shown as a toast.
    var toast: Toast?
    /// True while an action runs; the stack ignores swipes until it's done.
    private(set) var isPerforming = false
    /// Goes up each time an action finishes, so the view can play a success haptic.
    private(set) var completedCount = 0

    private let performers: [ActionType: any ActionPerformer]
    private let photoLibrary: any PhotoLibraryProviding
    private let context: ModelContext
    @ObservationIgnored private var previews: [String: CGImage] = [:]

    init(
        performers: [ActionType: any ActionPerformer], photoLibrary: any PhotoLibraryProviding,
        context: ModelContext
    ) {
        self.performers = performers
        self.photoLibrary = photoLibrary
        self.context = context
    }

    /// Runs the card's action. On success the item becomes `done` and leaves the stack; on
    /// failure it stays and the toast says why. Returns whether the card left.
    @discardableResult
    func perform(_ item: ScreenshotItem) async -> Bool {
        guard !isPerforming, let result = item.result else { return false }
        guard let performer = performers[result.type] else {
            toast = Toast(message: ActionError.unsupported(result.type).localizedDescription, isError: true)
            return false
        }
        isPerforming = true
        defer { isPerforming = false }
        do {
            let outcome = try await performer.perform(result, assetID: item.assetID)
            finish(item, as: .done)
            completedCount += 1
            toast = Toast(message: outcome.message, isError: false)
            Log.scan.info("card_done type=\(result.type.rawValue, privacy: .public)")
            return true
        } catch {
            toast = Toast(message: Self.message(for: error), isError: true)
            Log.scan.error("card_action_failed type=\(result.type.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Marks the card `skipped` (swiped left); it never comes back as a card.
    @discardableResult
    func skip(_ item: ScreenshotItem) -> Bool {
        guard !isPerforming else { return false }
        // The next scan offers it in the Clean up tab if it's blurry, a duplicate, or useless.
        item.skipReason = .swipedLeft
        finish(item, as: .skipped)
        toast = Toast(message: "Skipped.", isError: false)
        Log.scan.info("card_skipped")
        return true
    }

    /// Replaces the card's result with the user's fixes from the edit sheet.
    func save(_ result: ActionResult, for item: ScreenshotItem) {
        item.result = result
        item.processedAt = Date()
        save()
    }

    /// Card-sized image of the screenshot, cached for the life of the screen.
    func preview(for assetID: String) async -> CGImage? {
        if let cached = previews[assetID] { return cached }
        let image = await photoLibrary.loadPreview(
            assetID: assetID, maxPixels: ScanConfig.cardImageMaxPixels)
        previews[assetID] = image
        return image
    }

    private func finish(_ item: ScreenshotItem, as status: ScanStatus) {
        item.status = status
        item.processedAt = Date()
        save()
        previews[item.assetID] = nil
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.scan.error("card_save_failed error=\(String(describing: error), privacy: .public)")
        }
    }

    /// The UI never shows raw errors: `ActionError` has its own message, anything else is generic.
    private static func message(for error: any Error) -> String {
        (error as? ActionError)?.errorDescription ?? "Something went wrong. Try again."
    }
}
