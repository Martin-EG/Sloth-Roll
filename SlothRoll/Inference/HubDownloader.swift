import Foundation
import HuggingFace
import MLXLMCommon

/// Adapts swift-huggingface's `HubClient` to mlx-swift-lm's `Downloader` protocol.
///
/// Same bridge as the package's `#hubDownloader()` macro, written out by hand so the
/// project needs no macro trust prompt. Snapshots live in Application Support (iOS never
/// purges it, unlike Caches), and a cached snapshot is returned without any network call.
struct HubDownloader: MLXLMCommon.Downloader {
    private let upstream: HubClient

    init(upstream: HubClient = HubClient(cache: HubCache(cacheDirectory: Self.cacheDirectory))) {
        self.upstream = upstream
    }

    static var cacheDirectory: URL {
        URL.applicationSupportDirectory.appending(
            path: InferenceConfig.modelCacheFolder, directoryHint: .isDirectory)
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = Repo.ID(rawValue: id) else {
            throw InferenceError.loadFailed(reason: "Invalid model ID: \(id)")
        }
        return try await upstream.downloadSnapshot(
            of: repoID,
            revision: revision ?? "main",
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}
