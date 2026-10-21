/// Where one library image is in the scan pipeline.
enum ScanStatus: String, Codable, Sendable, CaseIterable {
    /// Seen but not triaged yet.
    case pending
    /// Passed triage; waiting for the extraction model.
    case triaged
    /// The model produced a usable action (event, place, receipt), ready for the swipe UI.
    case extracted
    /// The user acted on it (swiped).
    case done
    /// Not worth the model (see `SkipReason`), or the model said "none".
    case skipped
    /// The model's answers couldn't be used, even after the retry.
    case failed
}
