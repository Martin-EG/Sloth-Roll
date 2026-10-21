import CoreGraphics

/// Contract for the on-device vision-language model, so features and tests never depend on MLX.
protocol VLMServing: Sendable {
    /// Identifier of the model this service runs (for display and logs).
    var modelID: String { get }

    /// Download progress in 0...1 while `load()` runs. Single consumer; observe it once.
    var downloadProgress: AsyncStream<Double> { get }

    /// Downloads (first time only) and loads the model into memory. No-op if already loaded.
    func load() async throws

    /// Runs one image + prompt through the model and returns its text answer.
    func describe(image: CGImage, prompt: String) async throws -> String

    /// Frees the model and MLX buffers.
    func unload() async
}
