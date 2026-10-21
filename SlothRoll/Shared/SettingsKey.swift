/// UserDefaults keys for the few preferences kept with `@AppStorage`.
enum SettingsKey {
    /// Bool: the first-launch screens (and model download) are done.
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// Int: new screenshots read per scan (one of `PipelineConfig.scanLimitOptions`).
    static let scanLimit = "scanLimit"
}
