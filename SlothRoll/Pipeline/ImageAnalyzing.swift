import CoreGraphics

/// Measures blur and computes a feature print for one image, so tests can swap in fakes.
protocol ImageAnalyzing: Sendable {
    /// Nil when the image can't be measured (too small, or drawing failed).
    func signals(for image: CGImage) async -> ImageSignals?
}
