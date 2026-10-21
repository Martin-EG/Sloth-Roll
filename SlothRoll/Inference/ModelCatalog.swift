import MLXLMCommon

/// Single source of truth for which vision-language model the app downloads and runs.
enum ModelCatalog {
    /// Smallest Qwen VL 4-bit model on mlx-community. Swap this ID to try another model.
    static let spikeModelID = "mlx-community/Qwen3-VL-2B-Instruct-4bit"

    /// Total size of the files fetched for `spikeModelID` (weights + tokenizer + configs).
    static let spikeModelDownloadBytes: Int64 = 1_798_023_774

    /// Qwen chat models end turns with `<|im_end|>`; stop generation there.
    static let qwenEndOfTurnToken = "<|im_end|>"

    static var spike: ModelConfiguration {
        ModelConfiguration(id: spikeModelID, extraEOSTokens: [qwenEndOfTurnToken])
    }
}
