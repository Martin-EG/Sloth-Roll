import Foundation
import Observation
import UIKit

/// Drives the scan screen: pick what to scan (all recent photos or one album), start, stop,
/// and show the coordinator's progress.
@Observable
@MainActor
final class ScanViewModel {
    let coordinator: ScanCoordinator
    /// Albums offered in the picker; filled by `loadAlbums()`.
    private(set) var albums: [PhotoAlbum] = []
    private(set) var isLoadingAlbums = false
    /// Photos access was refused while loading albums.
    private(set) var albumsNeedAccess = false

    private let photoLibrary: any PhotoLibraryProviding

    init(coordinator: ScanCoordinator, photoLibrary: any PhotoLibraryProviding) {
        self.coordinator = coordinator
        self.photoLibrary = photoLibrary
    }

    var phase: ScanPhase { coordinator.phase }
    var isRunning: Bool { coordinator.isRunning }
    var progress: (done: Int, total: Int) { coordinator.progress }
    var currentThumbnail: CGImage? { coordinator.currentThumbnail }
    var stats: ScanStats? { coordinator.lastStats }
    var isLimitedAccess: Bool { coordinator.access == .limited }
    var hasNoPhotoAccess: Bool { phase == .noPhotoAccess }

    /// Paused and stopped scans resume from where they left off.
    var scanButtonTitle: String {
        switch phase {
        case .pausedForMemory, .cancelled: "Resume scan"
        case .modelLoadFailed: "Try again"
        default: "Scan"
        }
    }

    /// The model couldn't load: shown as an error with the retry button.
    var errorMessage: String? {
        guard case .modelLoadFailed(let message) = phase else { return nil }
        return message
    }

    /// One line under the Scan button after a scan ends.
    var statusMessage: String? {
        switch phase {
        case .idle, .preparing, .triage, .loadingModel, .extract, .cleanup, .noPhotoAccess,
            .modelLoadFailed:
            nil
        case .finished: finishedMessage
        case .cancelled: "Stopped. Everything read so far is saved."
        case .pausedForMemory:
            "Paused: your iPhone is low on memory, so the model was unloaded. Close other apps, then resume."
        }
    }

    /// Warnings are orange; a normal finish is secondary text.
    var isStatusWarning: Bool { phase == .pausedForMemory }

    private var finishedMessage: String {
        // Camera photos don't count; a resumed scan reads leftovers without triaging.
        guard let stats, stats.triaged + stats.modelReads + stats.cleanupAsked > 0 else {
            return "No new screenshots since the last scan. Take some, then scan again."
        }
        return switch stats.extracted {
        case 0: "No events, places, or receipts in the new screenshots."
        case 1: "Found 1 new card."
        default: "Found \(stats.extracted) new cards."
        }
    }

    var progressLabel: String {
        let next = min(progress.done + 1, max(progress.total, 1))
        return switch phase {
        case .preparing: "Looking for new screenshots…"
        case .triage: "Checking \(next) of \(progress.total) for text…"
        case .loadingModel: "Loading the model…"
        case .extract: "Reading \(next) of \(progress.total)…"
        case .cleanup: "Looking for screenshots to clean up (\(next) of \(progress.total))…"
        default: ""
        }
    }

    /// Scans up to `limit` new screenshots (the Settings choice), only from `albumID` when set.
    func scan(limit: Int, albumID: String? = nil) async {
        // A locked phone suspends GPU work and stalls the scan for minutes.
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }
        Log.scan.info("scan_tapped limit=\(limit) album=\(albumID != nil)")
        await coordinator.scan(limit: limit, albumID: albumID)
        #if DEBUG
        if let stats { saveStats(stats) }
        #endif
    }

    func cancel() {
        coordinator.cancel()
    }

    /// Asks for Photos access if needed, then lists the albums for the picker.
    func loadAlbums() async {
        isLoadingAlbums = true
        defer { isLoadingAlbums = false }
        guard await photoLibrary.requestAccess().canRead else {
            albumsNeedAccess = true
            albums = []
            return
        }
        albumsNeedAccess = false
        albums = await photoLibrary.albums()
    }

    /// The saved album if it's in `albums` (call `loadAlbums()` first); nil means all recent
    /// photos. An album deleted in Photos falls back to all recent photos instead of
    /// scanning nothing.
    func validAlbumID(_ savedID: String) -> String? {
        albums.contains { $0.id == savedID } ? savedID : nil
    }

    /// Plain words for the current choice, e.g. "All recent photos" or "Album: Screenshots".
    static func sourceLabel(albumTitle: String?) -> String {
        guard let albumTitle, !albumTitle.isEmpty else { return "All recent photos" }
        return "Album: \(albumTitle)"
    }

    /// Opens this app's page in the Settings app, where Photos access is turned on.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    /// `-scanAutorun` starts a scan on launch; with `-scanReset` it first clears the cache.
    func autorunIfRequested(
        limit: Int, albumID: String? = nil,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(ScanConfig.autorunArgument), phase == .idle else { return }
        if arguments.contains(ScanConfig.resetArgument) { coordinator.resetCache() }
        await scan(limit: limit, albumID: albumID)
    }

    private func saveStats(_ stats: ScanStats) {
        do {
            let url = URL.documentsDirectory.appending(path: ScanConfig.statsFileName)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(stats).write(to: url, options: .atomic)
        } catch {
            Log.scan.error("stats_save_failed error=\(String(describing: error), privacy: .public)")
        }
    }
    #endif
}
