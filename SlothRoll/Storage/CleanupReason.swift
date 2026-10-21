/// Why a skipped screenshot is offered for deletion in the Clean up tab.
enum CleanupReason: String, Codable, Sendable, CaseIterable {
    /// Laplacian variance below `PipelineConfig.blurSharpnessThreshold`.
    case blurry
    /// A near-duplicate of a newer screenshot (the newest of each group is kept).
    case duplicate
    /// The model answered "no" to "Is this screenshot still useful to keep?".
    case notUseful
}
