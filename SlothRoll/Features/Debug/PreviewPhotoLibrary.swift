#if DEBUG
/// Fake album of placeholder screenshots so the eval screen previews without Photos access.
struct PreviewPhotoLibrary: PhotoLibraryProviding {
    var imageCount = 3

    func requestAccess() async -> Bool { true }

    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String] {
        (1...imageCount).map { "preview-\($0)" }
    }

    func loadImage(assetID: String) async -> LibraryImage? {
        guard let image = PreviewVLM.sampleImage() else { return nil }
        return LibraryImage(assetID: assetID, image: image, thumbnail: image)
    }
}
#endif
