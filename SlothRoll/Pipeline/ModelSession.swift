/// Loads the extraction model at most once per scan and unloads it at the end, so extraction
/// and the cleanup question share one load.
@MainActor
final class ModelSession {
    private let vlm: any VLMServing
    private(set) var isLoaded = false

    init(vlm: any VLMServing) {
        self.vlm = vlm
    }

    /// Loads unless already loaded and returns how long it took (zero when it was loaded).
    func load() async throws -> Duration {
        guard !isLoaded else { return .zero }
        let clock = ContinuousClock()
        let start = clock.now
        try await vlm.load()
        isLoaded = true
        return start.duration(to: clock.now)
    }

    /// One model at a time, and the swipe UI doesn't need it: frees the ~2 GB.
    func unloadIfLoaded() async {
        guard isLoaded else { return }
        await vlm.unload()
        isLoaded = false
    }
}
