/// UserDefaults keys for the few preferences kept with `@AppStorage`.
enum SettingsKey {
    /// Bool: the first-launch screens (and model download) are done.
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// Int: new screenshots read per scan (one of `PipelineConfig.scanLimitOptions`).
    static let scanLimit = "scanLimit"
    /// String: `PhotoAlbum.id` the Scan button reads from; empty means all recent photos.
    static let scanAlbumID = "scanAlbumID"
    /// String: that album's title, so the Scan screen can name it without asking Photos.
    static let scanAlbumTitle = "scanAlbumTitle"
}
