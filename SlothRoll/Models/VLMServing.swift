import CoreGraphics

/// Contract for the on-device vision-language model, so features and tests never depend on MLX.
protocol VLMServing: Sendable {
    /// Identifier of the model this service runs (for display and logs).
    var modelID: String { get }

    /// Bytes fetched by `download(progress:)` on first run (weights, tokenizer, configs).
    var downloadSizeBytes: Int64 { get }

    /// Download progress in 0...1 while `load()` runs. Single consumer; observe it once.
    var downloadProgress: AsyncStream<Double> { get }

    /// True when the model files are already on disk, so loading needs no network.
    func isDownloaded() async -> Bool

    /// Fetches the model files to disk without loading them into memory. `progress` gets
    /// 0...1. Returns at once if they're already there.
    func download(progress: @escaping @Sendable (Double) -> Void) async throws

    /// Downloads (first time only) and loads the model into memory. No-op if already loaded.
    func load() async throws

    /// Runs one image + prompt through the model and returns its text answer.
    func describe(image: CGImage, prompt: String) async throws -> String

    /// Frees the model and MLX buffers.
    func unload() async
}
