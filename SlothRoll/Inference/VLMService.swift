import CoreGraphics
import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM
import os

/// Owns the one loaded vision-language model: download, load, run, unload. No UI code.
actor VLMService: VLMServing {
    nonisolated let modelID: String
    nonisolated let downloadProgress: AsyncStream<Double>
    private let progressContinuation: AsyncStream<Double>.Continuation

    private let configuration: ModelConfiguration
    private let logger = Logger(
        subsystem: InferenceConfig.logSubsystem, category: InferenceConfig.logCategory)

    private var container: ModelContainer?
    private var loadTask: Task<ModelContainer, any Error>?

    init(configuration: ModelConfiguration = ModelCatalog.spike) {
        self.configuration = configuration
        self.modelID = configuration.name
        (downloadProgress, progressContinuation) = AsyncStream.makeStream(
            of: Double.self, bufferingPolicy: .bufferingNewest(1))
    }

    func load() async throws {
        if container != nil { return }

        // A load is already running (actor re-entrancy): wait for it instead of starting another.
        if let loadTask {
            _ = try await loadTask.value
            return
        }

        Memory.cacheLimit = InferenceConfig.gpuCacheLimitBytes
        let configuration = configuration
        let continuation = progressContinuation
        continuation.yield(0)

        let task = Task {
            try await VLMModelFactory.shared.loadContainer(
                from: HubDownloader(),
                using: TransformersTokenizerLoader(),
                configuration: configuration
            ) { progress in
                continuation.yield(progress.fractionCompleted)
            }
        }
        loadTask = task
        defer { loadTask = nil }

        do {
            container = try await task.value
            continuation.yield(1)
            logger.info("Loaded \(configuration.name, privacy: .public)")
        } catch {
            logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
            throw InferenceError.loadFailed(reason: error.localizedDescription)
        }
    }

    func describe(image: CGImage, prompt: String) async throws -> String {
        guard let container else { throw InferenceError.modelNotLoaded }

        // Fresh session per call: no chat history or KV cache carried between screenshots.
        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(
                maxTokens: InferenceConfig.maxOutputTokens,
                temperature: InferenceConfig.temperature),
            processing: UserInput.Processing(maxPixels: InferenceConfig.maxImagePixels)
        )

        let output: String
        do {
            output = try await session.respond(to: prompt, image: .ciImage(CIImage(cgImage: image)))
        } catch {
            logger.error("Generation failed: \(error.localizedDescription, privacy: .public)")
            throw InferenceError.generationFailed(reason: error.localizedDescription)
        }
        Memory.clearCache()

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InferenceError.emptyOutput }
        return trimmed
    }

    func unload() {
        loadTask?.cancel()
        loadTask = nil
        container = nil
        Memory.clearCache()
        progressContinuation.yield(0)
        logger.info("Unloaded model")
    }
}
