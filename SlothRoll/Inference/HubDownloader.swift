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

    /// The snapshot folder if the weights are already on disk. Never touches the network.
    func cachedSnapshot(id: String, revision: String?) async -> URL? {
        guard
            let repoID = Repo.ID(rawValue: id),
            let folder = try? await upstream.downloadSnapshot(
                of: repoID, revision: revision ?? "main",
                matching: InferenceConfig.weightFilePatterns, localFilesOnly: true)
        else { return nil }
        let files =
            (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
            ?? []
        return files.contains { $0.pathExtension == InferenceConfig.weightFileExtension } ? folder : nil
    }

    /// Creates the cache folder and keeps it out of iCloud backups: the model can always be
    /// downloaded again, and ~2 GB would eat the user's backup space.
    static func prepareCacheDirectory() throws {
        var folder = cacheDirectory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
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
