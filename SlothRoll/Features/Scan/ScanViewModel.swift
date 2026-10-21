import Foundation
import Observation
import UIKit

/// Drives the scan screen: start, stop, and show the coordinator's progress.
@Observable
@MainActor
final class ScanViewModel {
    let coordinator: ScanCoordinator

    init(coordinator: ScanCoordinator) {
        self.coordinator = coordinator
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
        case .idle, .preparing, .triage, .loadingModel, .extract, .noPhotoAccess, .modelLoadFailed:
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
        guard let stats, stats.triaged + stats.modelReads > 0 else {
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
        default: ""
        }
    }

    /// Scans up to `limit` new screenshots (the Settings choice).
    func scan(limit: Int) async {
        // A locked phone suspends GPU work and stalls the scan for minutes.
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }
        Log.scan.info("scan_tapped limit=\(limit)")
        await coordinator.scan(limit: limit)
        #if DEBUG
        if let stats { saveStats(stats) }
        #endif
    }

    func cancel() {
        coordinator.cancel()
    }

    /// Opens this app's page in the Settings app, where Photos access is turned on.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    /// `-scanAutorun` starts a scan on launch; with `-scanReset` it first clears the cache.
    func autorunIfRequested(
        limit: Int, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(ScanConfig.autorunArgument), phase == .idle else { return }
        if arguments.contains(ScanConfig.resetArgument) { coordinator.resetCache() }
        await scan(limit: limit)
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
