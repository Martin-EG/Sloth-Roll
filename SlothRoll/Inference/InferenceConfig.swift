import Foundation

/// Tunables for on-device inference (limits, sampling, image budget).
enum InferenceConfig {
    static let logSubsystem = "SlothRoll"
    static let logCategory = "inference"

    /// Folder under Application Support where downloaded model snapshots are kept.
    static let modelCacheFolder = "Models/huggingface"

    /// Hard cap on generated tokens so a runaway answer can't stall the UI.
    static let maxOutputTokens = 200

    /// Low temperature: we want factual descriptions, not creativity.
    static let temperature: Float = 0.2

    /// Upper bound on image pixels fed to the vision encoder (~576 vision tokens for Qwen3-VL).
    /// Higher reads small text better but costs prefill time and memory.
    static let maxImagePixels = 768 * 768

    /// Cap on MLX's reusable GPU buffer cache, so freed buffers are returned to the OS.
    static let gpuCacheLimitBytes = 256 * 1024 * 1024
}
