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
    /// Skipped screenshots asked "still useful?" this scan.
    var cleanupAsked = 0
    /// Screenshots waiting in the Clean up tab after this scan.
    var cleanupCandidates = 0

    var triageSeconds = 0.0
    var modelLoadSeconds = 0.0
    var extractSeconds = 0.0
    /// Measuring older skipped screenshots, the cleanup rules, and the "still useful?" reads.
    var cleanupSeconds = 0.0
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

    /// One `scan_done` line with every count and timing; `stop` says why the scan ended early.
    func log(stop: String) {
        let peakMB = Double(peakFootprintBytes ?? 0) / 1_048_576
        let sampledMB = Double(maxSampledFootprintBytes) / 1_048_576
        Log.pipeline.info(
            """
            scan_done new=\(newImages) triaged=\(triaged) candidates=\(candidates) \
            camera=\(cameraSkipped) unavailable=\(unavailable) reads=\(modelReads) \
            extracted=\(extracted) none=\(noAction) failed=\(failed) \
            cleanup_asked=\(cleanupAsked) cleanup_candidates=\(cleanupCandidates) \
            triage_s=\(triageSeconds, format: .fixed(precision: 2)) \
            load_s=\(modelLoadSeconds, format: .fixed(precision: 2)) \
            extract_s=\(extractSeconds, format: .fixed(precision: 2)) \
            cleanup_s=\(cleanupSeconds, format: .fixed(precision: 2)) \
            total_s=\(totalSeconds, format: .fixed(precision: 2)) \
            peak_mb=\(peakMB, format: .fixed(precision: 0)) sampled_mb=\(sampledMB, format: .fixed(precision: 0)) \
            stop=\(stop, privacy: .public)
            """)
    }
}
