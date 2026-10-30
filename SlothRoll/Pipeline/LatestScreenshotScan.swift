import CoreGraphics

/// Reads only the newest screenshot or saved image, for the Action Button / Siri / Shortcuts
/// entry point: triage it, and if it has text, load the model and read it. Skips the batch
/// steps (older leftovers, clean up) so its card is ready in seconds. Camera photos taken
/// after the screenshot are stepped over.
@MainActor
struct LatestScreenshotScan {
    let photoLibrary: any PhotoLibraryProviding
    let triage: any ImageTriaging
    let analyzer: any ImageAnalyzing
    let extractor: Extractor
    let store: ScanStore
    let model: ModelSession

    /// `report` gets each phase change with the image's thumbnail. Leaves the model loaded
    /// when it read something; the caller unloads it.
    func run(report: (ScanPhase, CGImage?) -> Void) async -> LatestScanOutcome {
        guard await photoLibrary.requestAccess().canRead else { return .noPhotoAccess }
        report(.triage, nil)
        for assetID in await photoLibrary.recentImageIDs(limit: PipelineConfig.latestScanWindow) {
            if let item = store.item(assetID: assetID) {
                if item.skipReason == .camera { continue }
                guard item.status == .triaged else { return Self.outcome(for: item) }
                // Passed triage in a stopped scan but was never read.
                guard let photo = await photoLibrary.loadImage(assetID: assetID) else { continue }
                return await read(item, photo: photo, report: report)
            }
            // Missing or only in iCloud: try the next one.
            guard let photo = await photoLibrary.loadImage(assetID: assetID) else { continue }
            if photo.source == .camera {
                store.record(
                    assetID: assetID, status: .skipped, skipReason: .camera,
                    capturedAt: photo.capturedAt)
                continue
            }
            report(.triage, photo.thumbnail)
            let isCandidate = await triage.isCandidate(photo.image)
            let signals = await analyzer.signals(for: photo.image)
            let item = store.record(
                assetID: assetID, status: isCandidate ? .triaged : .skipped,
                skipReason: isCandidate ? nil : .littleText, capturedAt: photo.capturedAt,
                signals: signals)
            guard isCandidate else { return .nothingFound }
            return await read(item, photo: photo, report: report)
        }
        return .noScreenshot
    }

    private func read(
        _ item: ScreenshotItem, photo: LibraryImage, report: (ScanPhase, CGImage?) -> Void
    ) async -> LatestScanOutcome {
        report(.loadingModel, photo.thumbnail)
        do {
            _ = try await model.load()
        } catch {
            Log.pipeline.error("latest_scan_model_load_failed error=\(String(describing: error), privacy: .public)")
            return .modelLoadFailed(message: error.localizedDescription)
        }
        report(.extract, photo.thumbnail)
        let extraction = await extractor.extractWithReport(
            image: photo.image, capturedAt: photo.capturedAt)
        store.complete(item, with: extraction)
        return Self.outcome(for: item)
    }

    private static func outcome(for item: ScreenshotItem) -> LatestScanOutcome {
        switch item.status {
        case .extracted: .card(item.result?.type ?? .none)
        case .done: .alreadyDone
        case .pending, .triaged, .skipped, .failed: .nothingFound
        }
    }
}
