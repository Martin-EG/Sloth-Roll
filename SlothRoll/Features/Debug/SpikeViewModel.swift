import CoreGraphics
import Foundation
import ImageIO
import Observation
import PhotosUI
import SwiftUI

/// Drives the day-1 spike screen: load the model, pick an image, describe it, record metrics.
@Observable
@MainActor
final class SpikeViewModel {
    enum Phase: Equatable {
        case idle, loading, ready, describing
    }

    private(set) var phase: Phase = .idle
    private(set) var downloadProgress: Double = 0
    private(set) var image: CGImage?
    private(set) var output: String?
    private(set) var errorMessage: String?

    private(set) var loadTime: Duration?
    private(set) var inferenceTime: Duration?
    /// Highest footprint seen while the last load or describe ran.
    private(set) var runPeakBytes: UInt64?
    /// Highest footprint since app launch (kernel ledger).
    private(set) var lifetimePeakBytes: UInt64?
    private(set) var availableBytes: UInt64?
    private(set) var describeCount = 0

    var modelID: String { vlm.modelID }
    var isModelLoaded: Bool { phase == .ready || phase == .describing }
    var canDescribe: Bool { phase == .ready && image != nil }

    private let vlm: any VLMServing

    init(vlm: any VLMServing) {
        self.vlm = vlm
        observeDownloadProgress()
        refreshMemory()
    }

    func loadModel() async {
        guard phase == .idle else { return }
        phase = .loading
        errorMessage = nil

        let (elapsed, peak, result) = await measure { try await self.vlm.load() }
        switch result {
        case .success:
            phase = .ready
            loadTime = elapsed
            runPeakBytes = peak
            Log.spike.info(
                "load_time_s=\(elapsed.seconds, format: .fixed(precision: 2)) peak_bytes=\(peak)")
        case .failure(let error):
            phase = .idle
            errorMessage = error.localizedDescription
            Log.spike.error("load_failed error=\(String(describing: error), privacy: .public)")
        }
        refreshMemory()
    }

    func unloadModel() async {
        await vlm.unload()
        phase = .idle
        downloadProgress = 0
        refreshMemory()
        Log.spike.info("unloaded")
    }

    func select(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        output = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                let decoded = Self.decodeImage(data)
            else {
                errorMessage = "Couldn't open that image. Pick another one."
                return
            }
            image = decoded
        } catch {
            errorMessage = "Couldn't open that image. Pick another one."
            Log.spike.error("image_load_failed error=\(String(describing: error), privacy: .public)")
        }
    }

    func describe() async {
        guard canDescribe, let image else { return }
        phase = .describing
        errorMessage = nil
        output = nil

        let (elapsed, peak, result) = await measure {
            try await self.vlm.describe(image: image, prompt: SpikeConfig.prompt)
        }
        phase = .ready
        inferenceTime = elapsed
        runPeakBytes = peak
        switch result {
        case .success(let text):
            output = text
            describeCount += 1
            Log.spike.info(
                """
                describe_ok n=\(self.describeCount) image=\(image.width)x\(image.height) \
                inference_time_s=\(elapsed.seconds, format: .fixed(precision: 2)) \
                peak_bytes=\(peak) output=\(text, privacy: .public)
                """)
        case .failure(let error):
            errorMessage = error.localizedDescription
            Log.spike.error("describe_failed error=\(String(describing: error), privacy: .public)")
        }
        refreshMemory()
    }

    // MARK: - Private

    private func observeDownloadProgress() {
        let stream = vlm.downloadProgress
        Task { [weak self] in
            for await value in stream {
                self?.downloadProgress = value
            }
        }
    }

    private func refreshMemory() {
        lifetimePeakBytes = MemoryProbe.peakFootprintBytes()
        availableBytes = MemoryProbe.availableBytes()
        Log.spike.info(
            """
            memory footprint=\(MemoryProbe.footprintBytes() ?? 0) \
            lifetime_peak=\(self.lifetimePeakBytes ?? 0) available=\(self.availableBytes ?? 0)
            """)
    }

    /// Runs `work`, timing it and sampling memory in the background to find the peak footprint.
    private func measure<T: Sendable>(
        _ work: @escaping @MainActor () async throws -> T
    ) async -> (Duration, UInt64, Result<T, any Error>) {
        let sampler = Task.detached(priority: .utility) { () -> UInt64 in
            var peak = MemoryProbe.footprintBytes() ?? 0
            while !Task.isCancelled {
                peak = max(peak, MemoryProbe.footprintBytes() ?? 0)
                try? await Task.sleep(for: SpikeConfig.memorySampleInterval)
            }
            return max(peak, MemoryProbe.footprintBytes() ?? 0)
        }

        let clock = ContinuousClock()
        let start = clock.now
        let result: Result<T, any Error>
        do {
            result = .success(try await work())
        } catch {
            result = .failure(error)
        }
        let elapsed = start.duration(to: clock.now)

        sampler.cancel()
        let peak = await sampler.value
        return (elapsed, peak, result)
    }

    private static func decodeImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

#if DEBUG
extension SpikeViewModel {
    /// Previews only: sets the picked image directly, since PhotosPicker can't run in the canvas.
    func setImageForPreview(_ image: CGImage) {
        self.image = image
    }
}
#endif
