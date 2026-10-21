import CoreGraphics

/// Constants for the scan screen.
enum ScanConfig {
    /// Debug launch argument: start a scan on launch with no taps (for timing runs on device).
    static let autorunArgument = "-scanAutorun"

    /// Debug launch argument: forget all scanned items before the autorun scan.
    static let resetArgument = "-scanReset"

    /// Debug: stats of the last scan, written to the app's Documents folder.
    static let statsFileName = "scan-stats.json"

    static let thumbnailSize = CGSize(width: 54, height: 96)
    static let thumbnailCornerRadius: CGFloat = 6

    // MARK: Card stack

    /// Long side, in pixels, of the screenshot image on a card (~3x a card's width in points).
    static let cardImageMaxPixels = 1000

    /// Cards drawn at once; the rest wait below the visible stack.
    static let visibleCards = 3

    /// Each card behind the top one is this much smaller and this many points lower.
    static let stackScaleStep: CGFloat = 0.05
    static let stackOffsetStep: CGFloat = 14

    /// Horizontal drag, in points, that counts as a swipe when released.
    static let swipeThreshold: CGFloat = 110

    /// Rotation at a drag of one full card width.
    static let maxRotationDegrees: Double = 12

    /// Strongest green / red tint, reached at `swipeThreshold`.
    static let maxTintOpacity: Double = 0.35

    /// How far a swiped card flies, in points, and how long it takes.
    static let flyOutDistance: CGFloat = 600
    static let flyOutSeconds: Double = 0.25

    static let cardCornerRadius: CGFloat = 24

    /// How long a toast stays up.
    static let toastDuration: Duration = .seconds(2.5)
}
