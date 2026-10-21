import Foundation

/// Counts, timings, and memory for one scan (logged, and written to a file in debug builds).
struct ScanStats: Codable, Sendable, Equatable {
    var startedAt = Date()
    /// Images in the library window that weren't in the cache yet.
    var newImages = 0
    /// Images OCR'd this scan (camera photos excluded).
    var triaged = 0
    var candidates = 0
    var cameraSkipped = 0
    /// Only in iCloud (or missing); left uncached so a later scan can try again.
    var unavailable = 0
    var extracted = 0
    var noAction = 0
    var failed = 0
    /// Candidates read by the model this scan, including ones left from earlier scans.
    var modelReads = 0

    var triageSeconds = 0.0
    var modelLoadSeconds = 0.0
    var extractSeconds = 0.0
    var totalSeconds = 0.0

    /// Highest footprint since app launch (what jetsam judges), read after the scan.
    var peakFootprintBytes: UInt64?
    /// Highest footprint sampled after each item during this scan.
    var maxSampledFootprintBytes: UInt64 = 0

    /// Mean model time per read, or nil when nothing was read.
    var secondsPerRead: Double? {
        modelReads > 0 ? extractSeconds / Double(modelReads) : nil
    }

    mutating func sampleMemory() {
        maxSampledFootprintBytes = max(maxSampledFootprintBytes, MemoryProbe.footprintBytes() ?? 0)
    }
}
