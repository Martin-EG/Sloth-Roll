import CoreGraphics

/// Constants for the Clean up screen.
enum CleanupConfig {
    /// Narrowest grid cell, in points; the grid fits as many columns as it can.
    static let gridMinCellWidth: CGFloat = 104
    static let gridSpacing: CGFloat = 8

    /// Width / height of a cell, close to an iPhone screenshot.
    static let cellAspectRatio: CGFloat = 9.0 / 19.5
    static let cellCornerRadius: CGFloat = 10

    /// Long side, in pixels, of a grid thumbnail (~3x a cell's height in points).
    static let thumbnailMaxPixels = 600

    /// How dim an unselected cell is drawn.
    static let unselectedOpacity: Double = 0.45

    /// How long a toast stays up.
    static let toastDuration: Duration = .seconds(3)
}
