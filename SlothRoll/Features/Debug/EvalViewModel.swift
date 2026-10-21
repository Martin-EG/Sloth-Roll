#if DEBUG
import Foundation
import Observation
import UIKit

/// Drives the debug eval screen: load the model, run Triage + Extractor over every image in
/// the test album, collect timings, and let a human mark each answer right or wrong.
@Observable
@MainActor
final class EvalViewModel {
    enum Phase: Equatable {
        case idle, loadingModel, ready, running
    }

    private(set) var phase: Phase = .idle
    private(set) var downloadProgress: Double = 0
    private(set) var rows: [EvalRow] = []
    /// Images processed and total in the current run.
    private(set) var progress: (done: Int, total: Int) = (0, 0)
    private(set) var skippedAssetIDs: [String] = []
    private(set) var errorMessage: String?

    var modelID: String { vlm.modelID }
    var isModelLoaded: Bool { phase == .ready || phase == .running }
    var summary: EvalSummary { EvalSummary(rows: rows) }

    private let vlm: any VLMServing
    private let photoLibrary: any PhotoLibraryProviding
    private let extractor: Extractor
    private let triage: Triage
    private let store: EvalReportStore
    private var isCancelling = false

    init(
        vlm: any VLMServing, photoLibrary: any PhotoLibraryProviding,
        triage: Triage = Triage(), store: EvalReportStore = EvalReportStore()
    ) {
        self.vlm = vlm
        self.photoLibrary = photoLibrary
        self.extractor = Extractor(vlm: vlm)
        self.triage = triage
        self.store = store
        observeDownloadProgress()
    }

    func loadModel() async {
        guard phase == .idle else { return }
        phase = .loadingModel
        errorMessage = nil
        do {
            try await vlm.load()
            phase = .ready
        } catch {
            phase = .idle
            errorMessage = error.localizedDescription
            Log.eval.error("load_failed error=\(String(describing: error), privacy: .public)")
        }
    }

    func unloadModel() async {
        guard phase == .ready else { return }
        await vlm.unload()
        phase = .idle
        downloadProgress = 0
    }

    /// Runs the whole album. Marks from the previous saved report carry over by asset ID.
    func run() async {
        guard phase == .ready else { return }
        phase = .running
        isCancelling = false
        errorMessage = nil
        skippedAssetIDs = []
        rows = []
        // Keep the screen on: a locked phone suspends the app and stalls timings by minutes.
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = false
            phase = .ready
        }

        guard await photoLibrary.requestAccess().canRead else {
            errorMessage = PipelineError.photoAccessDenied.localizedDescription
            return
        }
        let assetIDs: [String]
        do {
            assetIDs = try await photoLibrary.assetIDs(inAlbum: EvalConfig.albumName)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let previousMarks = Self.marks(from: store.load())
        progress = (0, assetIDs.count)
        Log.eval.info("run_start images=\(assetIDs.count) model=\(self.modelID, privacy: .public)")

        for assetID in assetIDs {
            if isCancelling { break }
            await evaluate(assetID: assetID, mark: previousMarks[assetID])
            progress.done += 1
        }

        saveReport()
        logSummary()
    }

    func cancel() {
        isCancelling = true
    }

    func setMark(_ mark: EvalMark?, for rowID: EvalRow.ID) {
        guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return }
        rows[index].mark = mark
        if phase != .running { saveReport() }
    }

    /// Lets a device run go hands-free: `-evalAutorun` loads the model and runs the album.
    func autorunIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) async {
        guard arguments.contains(EvalConfig.autorunArgument), phase == .idle, rows.isEmpty
        else { return }
        await loadModel()
        await run()
    }

    // MARK: - Private

    private func evaluate(assetID: String, mark: EvalMark?) async {
        guard let photo = await photoLibrary.loadImage(assetID: assetID) else {
            skippedAssetIDs.append(assetID)
            Log.eval.error("image_skipped asset=\(assetID, privacy: .public)")
            return
        }
        let scan = await triage.scanText(in: photo.image)
        let report = await extractor.extractWithReport(
            image: photo.image, capturedAt: photo.capturedAt)
        rows.append(
            EvalRow(
                assetID: assetID, thumbnail: photo.thumbnail, capturedAt: photo.capturedAt,
                source: photo.source, report: report, textScan: scan, mark: mark))

        Log.eval.info(
            """
            row n=\(self.rows.count) type=\(report.result.type.rawValue, privacy: .public) \
            confidence=\(report.result.confidence.rawValue, privacy: .public) \
            extraction_s=\(report.duration.seconds, format: .fixed(precision: 2)) \
            attempts=\(report.attempts) fallback=\(report.usedFallback) \
            ocr_s=\(scan.duration.seconds, format: .fixed(precision: 3)) \
            ocr_chars=\(scan.characterCount) source=\(photo.source.rawValue, privacy: .public) title=\(report.result.title)
            """)
    }

    private func saveReport() {
        store.save(
            EvalReport(
                modelID: modelID, createdAt: Date(), albumCount: progress.total,
                skippedAssetIDs: skippedAssetIDs, rows: rows))
    }

    private func logSummary() {
        let summary = summary
        let counts = ActionType.allCases
            .map { "\($0.rawValue)=\(summary.countsByType[$0, default: 0])" }
            .joined(separator: " ")
        Log.eval.info(
            """
            run_done images=\(summary.total) skipped=\(self.skippedAssetIDs.count) \(counts, privacy: .public) \
            avg_extraction_s=\(summary.averageExtraction?.seconds ?? 0, format: .fixed(precision: 2)) \
            avg_ocr_s=\(summary.averageOCR?.seconds ?? 0, format: .fixed(precision: 3)) \
            retries=\(summary.retryCount) fallbacks=\(summary.fallbackCount) \
            no_text=\(summary.noTextCount) marked=\(summary.markedCount) correct=\(summary.correctCount)
            """)
    }

    private func observeDownloadProgress() {
        let stream = vlm.downloadProgress
        Task { [weak self] in
            for await value in stream {
                self?.downloadProgress = value
            }
        }
    }

    private static func marks(from report: EvalReport?) -> [String: EvalMark] {
        guard let report else { return [:] }
        return Dictionary(
            report.rows.compactMap { row in row.mark.map { (row.assetID, $0) } },
            uniquingKeysWith: { first, _ in first })
    }
}
#endif
