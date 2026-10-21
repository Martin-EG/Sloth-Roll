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

    /// Paused and stopped scans resume from where they left off.
    var scanButtonTitle: String {
        switch phase {
        case .pausedForMemory, .cancelled: "Resume scan"
        default: "Scan"
        }
    }

    var statusMessage: String? {
        switch phase {
        case .idle, .preparing, .triage, .loadingModel, .extract: nil
        case .finished: "Scan finished."
        case .cancelled: "Stopped. Everything read so far is saved."
        case .pausedForMemory:
            "Paused: your iPhone is low on memory, so the model was unloaded. Close other apps, then resume."
        case .failed(let message): message
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

    func scan() async {
        // A locked phone suspends GPU work and stalls the scan for minutes.
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }
        Log.scan.info("scan_tapped")
        await coordinator.scan()
        #if DEBUG
        if let stats { saveStats(stats) }
        #endif
    }

    func cancel() {
        coordinator.cancel()
    }

    #if DEBUG
    func resetCache() {
        coordinator.resetCache()
    }

    /// `-scanAutorun` starts a scan on launch; with `-scanReset` it first clears the cache.
    func autorunIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) async {
        guard arguments.contains(ScanConfig.autorunArgument), phase == .idle else { return }
        if arguments.contains(ScanConfig.resetArgument) { resetCache() }
        await scan()
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
