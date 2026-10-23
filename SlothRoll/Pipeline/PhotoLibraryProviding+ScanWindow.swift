extension PhotoLibraryProviding {
    /// The newest images a scan looks at (up to `PipelineConfig.libraryScanWindow`): one
    /// album's when `albumID` is set, otherwise the whole library's.
    func scanWindowIDs(albumID: String?) async -> [String] {
        let window = PipelineConfig.libraryScanWindow
        guard let albumID else { return await recentImageIDs(limit: window) }
        return await imageIDs(inAlbumID: albumID, limit: window)
    }
}
