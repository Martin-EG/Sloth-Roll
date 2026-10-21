import Foundation
import MLXLMCommon
import Tokenizers

/// Loads a swift-transformers tokenizer from a model folder for mlx-swift-lm.
struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TransformersTokenizer(upstream: upstream)
    }
}
