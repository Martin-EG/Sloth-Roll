import CoreGraphics

/// Access to the user's photo library (reading, plus moving screenshots to Recently Deleted),
/// so features and tests don't touch PhotoKit.
protocol PhotoLibraryProviding: Sendable {
    /// Asks for library access if needed and says how much was granted.
    func requestAccess() async -> PhotoAccess

    /// Local identifiers of the newest images in the library (all sources), newest first.
    func recentImageIDs(limit: Int) async -> [String]

    /// Local identifiers of every image in the album with this exact title, oldest first.
    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String]

    /// Loads one image from the device, downscaled for the model, with its `ImageSource`.
    /// Nil if it's missing or only in iCloud.
    func loadImage(assetID: String) async -> LibraryImage?

    /// A display-size image for a review card (long side about `maxPixels`). Nil if it's
    /// missing or only in iCloud.
    func loadPreview(assetID: String, maxPixels: Int) async -> CGImage?

    /// Moves these assets to Recently Deleted after iOS's own confirmation. False when the
    /// user declines; ids no longer in the library are ignored.
    func deleteAssets(ids: [String]) async throws(PipelineError) -> Bool
}
