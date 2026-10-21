/// Read-only access to the user's photo library, so features and tests don't touch PhotoKit.
protocol PhotoLibraryProviding: Sendable {
    /// Asks for library access if needed. Returns true when reading is allowed.
    func requestAccess() async -> Bool

    /// Local identifiers of the screenshots (not camera photos) in the album with this exact
    /// title, oldest first.
    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String]

    /// Loads one image from the device. Nil if it's missing or only in iCloud.
    func loadImage(assetID: String) async -> LibraryImage?
}
