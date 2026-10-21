import CoreGraphics

/// Cheap yes/no gate run before the extraction model, so it only reads likely actions.
protocol ImageTriaging: Sendable {
    /// True when the image might hold an event, place, or receipt.
    func isCandidate(_ image: CGImage) async -> Bool
}
