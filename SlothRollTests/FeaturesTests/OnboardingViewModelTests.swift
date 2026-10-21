import CoreGraphics
import Foundation
import Testing

@testable import SlothRoll

/// Model whose download fails a set number of times, then succeeds.
private actor DownloadVLM: VLMServing {
    nonisolated let modelID = "fake/download"
    nonisolated let downloadSizeBytes: Int64 = 1_000_000_000
    nonisolated let downloadProgress = AsyncStream<Double> { $0.finish() }

    private var failuresLeft: Int
    private var isOnDisk: Bool
    private(set) var downloadCalls = 0

    init(failures: Int = 0, isOnDisk: Bool = false) {
        self.failuresLeft = failures
        self.isOnDisk = isOnDisk
    }

    func isDownloaded() async -> Bool { isOnDisk }

    func download(progress: @escaping @Sendable (Double) -> Void) async throws {
        downloadCalls += 1
        progress(0.5)
        if failuresLeft > 0 {
            failuresLeft -= 1
            throw InferenceError.downloadFailed(reason: "offline")
        }
        isOnDisk = true
    }

    func load() async throws {}
    func describe(image: CGImage, prompt: String) async throws -> String { "" }
    func unload() async {}
}

@MainActor
struct OnboardingViewModelTests {
    @Test func freshInstallWaitsForTheUserThenDownloads() async {
        let vlm = DownloadVLM()
        let viewModel = OnboardingViewModel(vlm: vlm)

        await viewModel.checkExistingDownload()
        #expect(viewModel.state == .idle)

        await viewModel.download()
        #expect(viewModel.state == .done)
        #expect(await vlm.downloadCalls == 1)
    }

    @Test func failureShowsAUserMessageAndRetryWorks() async {
        let viewModel = OnboardingViewModel(vlm: DownloadVLM(failures: 1))
        await viewModel.checkExistingDownload()

        await viewModel.download()
        #expect(
            viewModel.state
                == .failed(message: InferenceError.downloadFailed(reason: "").localizedDescription))

        await viewModel.download()
        #expect(viewModel.state == .done)
    }

    @Test func modelAlreadyOnDiskSkipsTheDownload() async {
        let vlm = DownloadVLM(isOnDisk: true)
        let viewModel = OnboardingViewModel(vlm: vlm)

        await viewModel.checkExistingDownload()
        await viewModel.download()

        #expect(viewModel.state == .done)
        #expect(await vlm.downloadCalls == 0)
    }

    @Test func sizeIsShownInPlainUnits() {
        let viewModel = OnboardingViewModel(vlm: DownloadVLM())
        #expect(viewModel.downloadSizeText == Int64(1_000_000_000).formatted(.byteCount(style: .file)))
        #expect(viewModel.progressText == nil)
    }
}
