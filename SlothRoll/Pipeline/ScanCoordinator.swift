import CoreGraphics
import Foundation
import Observation
import SwiftData
import UIKit

/// Runs a scan from the photo library to stored results: triage every new image first (OCR,
/// blur, feature print), then load the extraction model and read only the candidates, one
/// image at a time, then fill the Clean up tab (rules, then "still useful?" for leftovers).
/// Each item is saved the moment it's done, so a crash or stop mid-scan loses nothing.
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
    private let analyzer: any ImageAnalyzing
    private let extractor: Extractor
    private let store: ScanStore
    private let cleanup: CleanupJudge
    private let model: ModelSession
    private let limit: Int
    private var stopRequest: StopRequest?

    init(
        vlm: any VLMServing, photoLibrary: any PhotoLibraryProviding,
        triage: any ImageTriaging, analyzer: any ImageAnalyzing, modelContext: ModelContext,
        limit: Int = PipelineConfig.scanLimit
    ) {
        self.vlm = vlm
        self.photoLibrary = photoLibrary
        self.triage = triage
        self.analyzer = analyzer
        self.extractor = Extractor(vlm: vlm)
        self.store = ScanStore(context: modelContext)
        self.cleanup = CleanupJudge(vlm: vlm, store: store)
        self.model = ModelSession(vlm: vlm)
        self.limit = limit
        // The coordinator lives as long as the app, so the observer is never removed.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMemoryWarning() }
        }
    }

    /// Scans the newest `limit` new images (the init's limit when nil), from one album when
    /// `albumID` is set, else from the whole library. Safe to call again after a stop or
    /// pause: cached images are skipped and triaged-but-unread ones are picked up first.
    func scan(limit: Int? = nil, albumID: String? = nil) async {
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
            phase = .noPhotoAccess
            return
        }

        await runTriage(stats: &stats, limit: limit ?? self.limit, albumID: albumID, clock: clock)
        if stopRequest == nil { await measureOlderSkippedItems(stats: &stats) }
        if stopRequest == nil { await runExtraction(stats: &stats, clock: clock) }
        if stopRequest == nil, !phase.isModelLoadFailure { await runCleanup(stats: &stats, clock: clock) }
        await model.unloadIfLoaded()

        currentThumbnail = nil
        stats.totalSeconds = start.duration(to: clock.now).seconds
        stats.peakFootprintBytes = MemoryProbe.peakFootprintBytes()
        lastStats = stats
        stats.log(stop: stopRequest.map { String(describing: $0) } ?? "none")
        if phase.isModelLoadFailure { return }
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

    /// "Rescan everything": forget every scanned item except the ones whose action already ran,
    /// so the next scan reads them again without re-adding an event or expense.
    func resetCache() {
        guard !isRunning else { return }
        store.deleteItemsNotDone()
        lastStats = nil
        phase = .idle
    }

    // MARK: - Phases

    /// OCR, blur, and feature print on every new image before any model is loaded (the image
    /// is already in memory, so cleanup never loads it twice). Camera photos are recorded as
    /// skipped and don't count toward `limit`.
    private func runTriage(
        stats: inout ScanStats, limit: Int, albumID: String?, clock: ContinuousClock
    ) async {
        let start = clock.now
        let known = store.knownAssetIDs()
        let fresh = await photoLibrary.scanWindowIDs(albumID: albumID)
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
            let signals = await analyzer.signals(for: photo.image)
            store.record(
                assetID: assetID, status: isCandidate ? .triaged : .skipped,
                skipReason: isCandidate ? nil : .littleText, capturedAt: photo.capturedAt,
                signals: signals)
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

    /// Blur and feature print for skipped items triaged before cleanup existed (or whose
    /// analysis failed), so the cleanup rules can judge them. Runs before the model loads.
    private func measureOlderSkippedItems(stats: inout ScanStats) async {
        await forEachPhoto(of: cleanup.itemsMissingSignals(), in: .cleanup, stats: &stats) {
            item, photo, _ in
            if let signals = await analyzer.signals(for: photo.image) { store.setSignals(signals, on: item) }
        }
    }

    /// Loads the model once per scan. False (and `phase` says why) when it can't load.
    private func loadModelIfNeeded(stats: inout ScanStats) async -> Bool {
        if model.isLoaded { return true }
        phase = .loadingModel
        do {
            stats.modelLoadSeconds += try await model.load().seconds
        } catch {
            Log.pipeline.error("scan_model_load_failed error=\(String(describing: error), privacy: .public)")
            phase = .modelLoadFailed(message: error.localizedDescription)
            return false
        }
        stats.sampleMemory()
        return true
    }

    private func runExtraction(stats: inout ScanStats, clock: ContinuousClock) async {
        let queue = store.itemsAwaitingExtraction()
        guard !queue.isEmpty, await loadModelIfNeeded(stats: &stats) else { return }

        let extractStart = clock.now
        // An item no longer on the device stays `triaged` and is retried next scan.
        await forEachPhoto(of: queue, in: .extract, stats: &stats) { item, photo, stats in
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
        }
        stats.extractSeconds = extractStart.duration(to: clock.now).seconds
    }

    /// Rules first (no model), then the "still useful?" question for what's left, reusing the
    /// model extraction loaded (or loading it if extraction had nothing to read).
    private func runCleanup(stats: inout ScanStats, clock: ContinuousClock) async {
        let start = clock.now
        await cleanup.applyRules()
        let queue = cleanup.itemsToAsk()
        if !queue.isEmpty, await loadModelIfNeeded(stats: &stats) {
            // An item no longer on the device stays unjudged and is asked about next scan.
            await forEachPhoto(of: queue, in: .cleanup, stats: &stats) { item, photo, stats in
                await cleanup.ask(about: item, image: photo.image)
                stats.cleanupAsked += 1
            }
        }
        stats.cleanupCandidates = cleanup.candidateCount()
        stats.cleanupSeconds = start.duration(to: clock.now).seconds
    }

    /// Loads each item's image in turn and hands it to `work`, updating progress and the
    /// thumbnail; stops after the current item on a stop request.
    private func forEachPhoto(
        of items: [ScreenshotItem], in phase: ScanPhase, stats: inout ScanStats,
        _ work: @MainActor (ScreenshotItem, LibraryImage, inout ScanStats) async -> Void
    ) async {
        guard !items.isEmpty else { return }
        self.phase = phase
        progress = (0, items.count)
        for item in items {
            if stopRequest != nil { break }
            guard let photo = await photoLibrary.loadImage(assetID: item.assetID) else {
                stats.unavailable += 1
                continue
            }
            currentThumbnail = photo.thumbnail
            await work(item, photo, &stats)
            progress.done += 1
            stats.sampleMemory()
        }
    }
}
