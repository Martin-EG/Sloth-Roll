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
}
