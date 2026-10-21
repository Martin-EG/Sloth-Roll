import CoreGraphics
import Foundation
import Observation
import SwiftData
import UIKit

/// Runs a scan from the photo library to stored results: triage every new image first (OCR),
/// then load the extraction model and read only the candidates, one image at a time. Each
/// item is saved the moment it's done, so a crash or stop mid-scan loses nothing.
@Observable
@MainActor
final class ScanCoordinator {
    private enum StopRequest {
        case cancel, memoryWarning
    }

    private(set) var phase: ScanPhase = .idle
    /// Items finished and total in the current phase.
    private(set) var progress: (done: Int, total: Int) = (0, 0)
    /// The image being triaged or read.
    private(set) var currentThumbnail: CGImage?
    /// Set after the first access request; `.limited` means only the picked photos are scanned.
    private(set) var access: PhotoAccess?
    private(set) var lastStats: ScanStats?

    var isRunning: Bool { phase.isRunning }

    private let vlm: any VLMServing
    private let photoLibrary: any PhotoLibraryProviding
    private let triage: any ImageTriaging
    private let extractor: Extractor
    private let store: ScanStore
    private let limit: Int
    private var stopRequest: StopRequest?

    init(
        vlm: any VLMServing, photoLibrary: any PhotoLibraryProviding,
        triage: any ImageTriaging, modelContext: ModelContext,
        limit: Int = PipelineConfig.scanLimit
    ) {
        self.vlm = vlm
        self.photoLibrary = photoLibrary
        self.triage = triage
        self.extractor = Extractor(vlm: vlm)
        self.store = ScanStore(context: modelContext)
        self.limit = limit
        // The coordinator lives as long as the app, so the observer is never removed.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMemoryWarning() }
        }
    }

    /// Scans the newest `limit` new images. Safe to call again after a stop or pause: cached
    /// images are skipped and triaged-but-unread ones are picked up first.
    func scan() async {
        guard !isRunning else { return }
        stopRequest = nil
        let clock = ContinuousClock()
        let start = clock.now
        var stats = ScanStats()
        phase = .preparing
        progress = (0, 0)

        let access = await photoLibrary.requestAccess()
        self.access = access
        guard access.canRead else {
            phase = .failed(message: PipelineError.photoAccessDenied.localizedDescription)
            return
        }

        await runTriage(stats: &stats, clock: clock)
        if stopRequest == nil {
            await runExtraction(stats: &stats, clock: clock)
        }

        currentThumbnail = nil
        stats.totalSeconds = start.duration(to: clock.now).seconds
        stats.peakFootprintBytes = MemoryProbe.peakFootprintBytes()
        lastStats = stats
        log(stats)
        if case .failed = phase { return }
        phase =
            switch stopRequest {
            case .cancel: .cancelled
            case .memoryWarning: .pausedForMemory
            case nil: .finished
            }
    }

    /// Stops after the current image; everything finished so far stays saved.
    func cancel() {
        guard isRunning else { return }
        stopRequest = .cancel
    }

    /// Finish the current item, unload the model, and pause. A later `scan()` resumes.
    func handleMemoryWarning() {
        Log.pipeline.error("memory_warning running=\(self.isRunning) phase=\(String(describing: self.phase), privacy: .public)")
        guard isRunning else { return }
        stopRequest = .memoryWarning
    }

    /// Debug: forget all scanned items so the next scan redoes them.
    func resetCache() {
        guard !isRunning else { return }
        store.deleteAllItems()
        lastStats = nil
        phase = .idle
    }

    // MARK: - Phases

    /// OCR on every new image before any model is loaded. Camera photos are recorded as
    /// skipped and don't count toward `limit`.
    private func runTriage(stats: inout ScanStats, clock: ContinuousClock) async {
        let start = clock.now
        let known = store.knownAssetIDs()
        let fresh = await photoLibrary.recentImageIDs(limit: PipelineConfig.libraryScanWindow)
            .filter { !known.contains($0) }
        stats.newImages = fresh.count
        phase = .triage
        progress = (0, min(fresh.count, limit))

        for assetID in fresh {
            if stopRequest != nil || stats.triaged >= limit { break }
            guard let photo = await photoLibrary.loadImage(assetID: assetID) else {
                stats.unavailable += 1
                continue
            }
            if photo.source == .camera {
                store.record(
                    assetID: assetID, status: .skipped, skipReason: .camera,
                    capturedAt: photo.capturedAt)
                stats.cameraSkipped += 1
                continue
            }
            currentThumbnail = photo.thumbnail
            let isCandidate = await triage.isCandidate(photo.image)
            store.record(
                assetID: assetID, status: isCandidate ? .triaged : .skipped,
                skipReason: isCandidate ? nil : .littleText, capturedAt: photo.capturedAt)
            stats.triaged += 1
            stats.candidates += isCandidate ? 1 : 0
            progress.done = stats.triaged
            stats.sampleMemory()
        }
        // The window held fewer usable images than the estimate (camera or iCloud-only ones).
        progress.total = progress.done
        stats.triageSeconds = start.duration(to: clock.now).seconds
        // Triage is Vision OCR: there is no triage model to unload before extraction.
    }

    private func runExtraction(stats: inout ScanStats, clock: ContinuousClock) async {
        let queue = store.itemsAwaitingExtraction()
        guard !queue.isEmpty else { return }

        phase = .loadingModel
        let loadStart = clock.now
        do {
            try await vlm.load()
        } catch {
            Log.pipeline.error("scan_model_load_failed error=\(String(describing: error), privacy: .public)")
            phase = .failed(message: error.localizedDescription)
            return
        }
        stats.modelLoadSeconds = loadStart.duration(to: clock.now).seconds
        stats.sampleMemory()

        phase = .extract
        progress = (0, queue.count)
        let extractStart = clock.now
        for item in queue {
            if stopRequest != nil { break }
            // Not on the device any more: stays `triaged` and is retried next scan.
            guard let photo = await photoLibrary.loadImage(assetID: item.assetID) else {
                stats.unavailable += 1
                continue
            }
            currentThumbnail = photo.thumbnail
            let report = await extractor.extractWithReport(
                image: photo.image, capturedAt: photo.capturedAt)
            store.complete(item, with: report)
            stats.modelReads += 1
            if report.usedFallback {
                stats.failed += 1
            } else if report.result.type == .none {
                stats.noAction += 1
            } else {
                stats.extracted += 1
            }
            progress.done += 1
            stats.sampleMemory()
        }
        stats.extractSeconds = extractStart.duration(to: clock.now).seconds
        // One model at a time, and the swipe UI doesn't need it: free the ~2 GB now.
        await vlm.unload()
    }

    private func log(_ stats: ScanStats) {
        let peakMB = Double(stats.peakFootprintBytes ?? 0) / 1_048_576
        let sampledMB = Double(stats.maxSampledFootprintBytes) / 1_048_576
        Log.pipeline.info(
            """
            scan_done new=\(stats.newImages) triaged=\(stats.triaged) candidates=\(stats.candidates) \
            camera=\(stats.cameraSkipped) unavailable=\(stats.unavailable) reads=\(stats.modelReads) \
            extracted=\(stats.extracted) none=\(stats.noAction) failed=\(stats.failed) \
            triage_s=\(stats.triageSeconds, format: .fixed(precision: 2)) \
            load_s=\(stats.modelLoadSeconds, format: .fixed(precision: 2)) \
            extract_s=\(stats.extractSeconds, format: .fixed(precision: 2)) \
            total_s=\(stats.totalSeconds, format: .fixed(precision: 2)) \
            peak_mb=\(peakMB, format: .fixed(precision: 0)) sampled_mb=\(sampledMB, format: .fixed(precision: 0)) \
            stop=\(String(describing: self.stopRequest), privacy: .public)
            """)
    }
}
