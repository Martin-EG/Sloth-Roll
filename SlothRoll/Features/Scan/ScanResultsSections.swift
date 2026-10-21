import SwiftData
import SwiftUI

/// Temporary: every stored result grouped by type, plus skip counts, until the swipe UI lands.
struct ScanResultsSections: View {
    @Query(sort: \ScreenshotItem.capturedAt, order: .reverse) private var items: [ScreenshotItem]

    var body: some View {
        let byType = Dictionary(grouping: items.filter { $0.result != nil }) {
            $0.status == .failed ? nil : $0.result?.type
        }
        ForEach(ActionType.allCases, id: \.self) { type in
            if let group = byType[type], !group.isEmpty {
                Section("\(type.rawValue.capitalized) (\(group.count))") {
                    ForEach(group, id: \.assetID) { ScanResultRow(item: $0) }
                }
            }
        }
        if let failed = byType[nil], !failed.isEmpty {
            Section("Couldn't read (\(failed.count))") {
                ForEach(failed, id: \.assetID) { ScanResultRow(item: $0) }
            }
        }
        if !items.isEmpty {
            Section("Cache") {
                ForEach(ScanStatus.allCases, id: \.self) { status in
                    let count = items.count(where: { $0.status == status })
                    if count > 0 {
                        LabeledContent(status.rawValue, value: "\(count)")
                    }
                }
                ForEach(SkipReason.allCases, id: \.self) { reason in
                    let count = items.count(where: { $0.skipReason == reason })
                    if count > 0 {
                        LabeledContent("skipped: \(reason.rawValue)", value: "\(count)")
                    }
                }
            }
            .monospacedDigit()
        }
    }
}
