/// One album the user can pick as the scan source (Photos' Screenshots album or one of theirs).
struct PhotoAlbum: Identifiable, Hashable, Sendable {
    /// `PHAssetCollection.localIdentifier`.
    let id: String
    let title: String
    /// Images in the album (videos don't count).
    let imageCount: Int
}
