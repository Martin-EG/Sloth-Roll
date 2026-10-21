#if DEBUG
import CoreGraphics

/// Fake album of placeholder screenshots so screens preview without Photos access.
struct PreviewPhotoLibrary: PhotoLibraryProviding {
    var imageCount = 3

    func requestAccess() async -> PhotoAccess { .full }

    func recentImageIDs(limit: Int) async -> [String] {
        Array((1...imageCount).map { "preview-\($0)" }.prefix(limit))
    }

    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String] {
        (1...imageCount).map { "preview-\($0)" }
    }

    func loadImage(assetID: String) async -> LibraryImage? {
        guard let image = PreviewVLM.sampleImage() else { return nil }
        return LibraryImage(assetID: assetID, image: image, thumbnail: image, capturedAt: nil,
            source: .screenshot)
    }

    func loadPreview(assetID: String, maxPixels: Int) async -> CGImage? {
        PreviewVLM.sampleImage()
    }

    func deleteAssets(ids: [String]) async throws(PipelineError) -> Bool { true }
}
#endif
