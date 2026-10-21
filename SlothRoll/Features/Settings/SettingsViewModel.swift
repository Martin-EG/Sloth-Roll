import Foundation
import Observation

/// Drives the Settings screen: model facts, whether the model is on the phone, and
/// "Rescan everything".
@Observable
@MainActor
final class SettingsViewModel {
    /// Nil until checked on appear.
    private(set) var isModelDownloaded: Bool?
    /// Set after a rescan so the screen can say what happens next.
    private(set) var didResetCache = false

    private let coordinator: ScanCoordinator
    private let vlm: any VLMServing

    init(coordinator: ScanCoordinator, vlm: any VLMServing) {
        self.coordinator = coordinator
        self.vlm = vlm
    }

    var modelID: String { vlm.modelID }
    var modelSizeText: String { vlm.downloadSizeBytes.formatted(.byteCount(style: .file)) }
    var isScanning: Bool { coordinator.isRunning }
    var lastStats: ScanStats? { coordinator.lastStats }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    func refreshModelStatus() async {
        isModelDownloaded = await vlm.isDownloaded()
    }

    /// Forgets scanned screenshots (cards already done stay done) so the next scan reads
    /// everything again.
    func rescanEverything() {
        guard !isScanning else { return }
        coordinator.resetCache()
        didResetCache = true
        Log.settings.info("cache_reset")
    }
}
