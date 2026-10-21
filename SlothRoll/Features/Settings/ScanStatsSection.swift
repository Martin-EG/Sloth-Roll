#if DEBUG
import SwiftUI

/// Debug: counts, timings, and peak memory of the last scan.
struct ScanStatsSection: View {
    let stats: ScanStats

    var body: some View {
        Section("Last scan") {
            LabeledContent("New images", value: "\(stats.newImages)")
            LabeledContent(
                "Checked / to the model", value: "\(stats.triaged) / \(stats.candidates)")
            LabeledContent(
                "Actions / none / failed",
                value: "\(stats.extracted) / \(stats.noAction) / \(stats.failed)")
            LabeledContent(
                "Clean up asked / offered", value: "\(stats.cleanupAsked) / \(stats.cleanupCandidates)")
            if stats.cameraSkipped + stats.unavailable > 0 {
                LabeledContent(
                    "Camera / iCloud-only skipped",
                    value: "\(stats.cameraSkipped) / \(stats.unavailable)")
            }
            LabeledContent("Total time", value: seconds(stats.totalSeconds))
            LabeledContent(
                "Triage / load / read / clean up",
                value: [
                    stats.triageSeconds, stats.modelLoadSeconds, stats.extractSeconds,
                    stats.cleanupSeconds,
                ]
                    .map(seconds).joined(separator: " / "))
            if let perRead = stats.secondsPerRead {
                LabeledContent("Per image read", value: seconds(perRead))
            }
            if let peak = stats.peakFootprintBytes {
                LabeledContent(
                    "Peak memory",
                    value: Int64(clamping: peak).formatted(.byteCount(style: .memory)))
            }
        }
        .monospacedDigit()
    }

    private func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + " s"
    }
}
#endif
