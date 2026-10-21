import Foundation
import Observation
import UIKit

/// Drives the first-launch screens: checks for an earlier model download and runs the
/// one-time download with progress and retry.
@Observable
@MainActor
final class OnboardingViewModel {
    private(set) var state: ModelDownloadState = .checking

    private let vlm: any VLMServing

    init(vlm: any VLMServing) {
        self.vlm = vlm
    }

    /// "1.8 GB"
    var downloadSizeText: String {
        vlm.downloadSizeBytes.formatted(.byteCount(style: .file))
    }

    /// "640 MB of 1.8 GB" while downloading.
    var progressText: String? {
        guard case .downloading(let fraction) = state else { return nil }
        let done = Int64(Double(vlm.downloadSizeBytes) * fraction)
        return "\(done.formatted(.byteCount(style: .file))) of \(downloadSizeText)"
    }

    /// Skips straight to "ready" when the files are already on disk (e.g. after a reinstall
    /// that kept app data).
    func checkExistingDownload() async {
        guard state == .checking else { return }
        state = await vlm.isDownloaded() ? .done : .idle
    }

    /// Starts (or retries) the download. Keeps the screen on: a locked phone pauses it.
    func download() async {
        switch state {
        case .idle, .failed: break
        case .checking, .downloading, .done: return
        }
        state = .downloading(fraction: 0)
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }
        Log.onboarding.info("download_started")
        do {
            try await vlm.download { [weak self] fraction in
                Task { @MainActor in self?.updateProgress(fraction) }
            }
            state = .done
            Log.onboarding.info("download_finished")
        } catch {
            state = .failed(message: Self.message(for: error))
            Log.onboarding.error("download_failed error=\(String(describing: error), privacy: .public)")
        }
    }

    private func updateProgress(_ fraction: Double) {
        // A late progress callback must not undo "done" or "failed".
        guard case .downloading = state else { return }
        state = .downloading(fraction: min(max(fraction, 0), 1))
    }

    /// The UI never shows raw errors: the live service throws `InferenceError`, whose
    /// descriptions are written for users; anything else gets a generic message.
    private static func message(for error: any Error) -> String {
        (error as? any LocalizedError)?.errorDescription
            ?? "The download stopped. Check your connection, then try again."
    }
}
