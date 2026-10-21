import CoreGraphics
import Testing

@testable import SlothRoll

/// Stand-in for the real model so the spike flow can be tested without MLX or a device GPU.
private actor FakeVLM: VLMServing {
    nonisolated let modelID = "fake/model"
    nonisolated let downloadProgress: AsyncStream<Double>
    private let continuation: AsyncStream<Double>.Continuation

    var shouldFailLoad = false
    private(set) var loadCount = 0
    private(set) var unloadCount = 0
    private(set) var lastPrompt: String?

    init(shouldFailLoad: Bool = false) {
        self.shouldFailLoad = shouldFailLoad
        (downloadProgress, continuation) = AsyncStream.makeStream(of: Double.self)
    }

    func load() async throws {
        loadCount += 1
        if shouldFailLoad { throw InferenceError.loadFailed(reason: "test") }
        continuation.yield(1)
    }

    func describe(image: CGImage, prompt: String) async throws -> String {
        lastPrompt = prompt
        return "A concert flyer. Contains an event."
    }

    func unload() async {
        unloadCount += 1
    }
}

@MainActor
struct SpikeViewModelTests {
    @Test func loadMovesToReadyAndRecordsLoadTime() async {
        let fake = FakeVLM()
        let viewModel = SpikeViewModel(vlm: fake)

        await viewModel.loadModel()

        #expect(viewModel.phase == .ready)
        #expect(viewModel.loadTime != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(await fake.loadCount == 1)
    }

    @Test func failedLoadShowsUserMessageAndStaysIdle() async {
        let viewModel = SpikeViewModel(vlm: FakeVLM(shouldFailLoad: true))

        await viewModel.loadModel()

        #expect(viewModel.phase == .idle)
        #expect(viewModel.errorMessage == InferenceError.loadFailed(reason: "").errorDescription)
    }

    @Test func describeIsDisabledWithoutImage() async {
        let viewModel = SpikeViewModel(vlm: FakeVLM())
        await viewModel.loadModel()

        #expect(viewModel.canDescribe == false)
        await viewModel.describe()
        #expect(viewModel.output == nil)
        #expect(viewModel.describeCount == 0)
    }

    @Test func unloadReturnsToIdle() async {
        let fake = FakeVLM()
        let viewModel = SpikeViewModel(vlm: fake)
        await viewModel.loadModel()

        await viewModel.unloadModel()

        #expect(viewModel.phase == .idle)
        #expect(await fake.unloadCount == 1)
    }
}
