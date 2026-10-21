import CoreGraphics
import Foundation
import Observation
import SwiftData

/// Drives the Clean up grid: selection (everything selected by default), thumbnails, and
/// moving the selected screenshots to Recently Deleted.
@Observable
@MainActor
final class CleanupViewModel {
    /// Result of the last delete, shown as a toast.
    var toast: Toast?
    /// True while iOS's delete confirmation is up or Photos is deleting.
    private(set) var isDeleting = false
    /// Asset IDs the user unselected; anything else is selected, so new candidates start selected.
    private(set) var unselected: Set<String> = []

    private let photoLibrary: any PhotoLibraryProviding
    private let context: ModelContext
    @ObservationIgnored private var thumbnails: [String: CGImage] = [:]

    init(photoLibrary: any PhotoLibraryProviding, context: ModelContext) {
        self.photoLibrary = photoLibrary
        self.context = context
    }

    func isSelected(_ item: ScreenshotItem) -> Bool {
        !unselected.contains(item.assetID)
    }

    func toggle(_ item: ScreenshotItem) {
        if unselected.contains(item.assetID) {
            unselected.remove(item.assetID)
        } else {
            unselected.insert(item.assetID)
        }
    }

    func selectedCount(in items: [ScreenshotItem]) -> Int {
        items.count(where: isSelected)
    }

    /// True when every item is selected (the toolbar then offers "Deselect all").
    func allSelected(in items: [ScreenshotItem]) -> Bool {
        items.allSatisfy(isSelected)
    }

    func toggleAll(in items: [ScreenshotItem]) {
        unselected = allSelected(in: items) ? Set(items.map(\.assetID)) : []
    }

    func deleteButtonTitle(count: Int) -> String {
        count == 1 ? "Delete 1 screenshot" : "Delete \(count) screenshots"
    }

    /// Asks Photos to delete the selected screenshots (iOS shows its own confirmation). On
    /// success they leave the app's cache and the unselected ones are kept for good; if the
    /// user declines, nothing changes.
    func deleteSelected(from items: [ScreenshotItem]) async {
        let selected = items.filter(isSelected)
        guard !isDeleting, !selected.isEmpty else { return }
        isDeleting = true
        defer { isDeleting = false }

        let deleted: Bool
        do {
            deleted = try await photoLibrary.deleteAssets(ids: selected.map(\.assetID))
        } catch {
            toast = Toast(message: error.localizedDescription, isError: true)
            return
        }
        guard deleted else {
            Log.cleanup.info("delete_declined count=\(selected.count)")
            return
        }

        let kept = items.filter { !isSelected($0) }
        let now = Date()
        for item in kept {
            item.cleanupReason = nil
            item.cleanupKeptAt = now
        }
        for item in selected {
            thumbnails[item.assetID] = nil
            context.delete(item)
        }
        save()
        unselected = []
        toast = Toast(message: Self.deletedMessage(count: selected.count), isError: false)
        Log.cleanup.info("deleted count=\(selected.count) kept=\(kept.count)")
    }

    /// Grid-sized image of the screenshot, cached for the life of the screen.
    func thumbnail(for assetID: String) async -> CGImage? {
        if let cached = thumbnails[assetID] { return cached }
        let image = await photoLibrary.loadPreview(
            assetID: assetID, maxPixels: CleanupConfig.thumbnailMaxPixels)
        thumbnails[assetID] = image
        return image
    }

    static func deletedMessage(count: Int) -> String {
        count == 1
            ? "Moved 1 screenshot to Recently Deleted."
            : "Moved \(count) screenshots to Recently Deleted."
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.cleanup.error("save_failed error=\(String(describing: error), privacy: .public)")
        }
    }
}
