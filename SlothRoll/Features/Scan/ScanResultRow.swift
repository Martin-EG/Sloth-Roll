import SwiftUI

/// One stored result: title and the fields the action will use.
struct ScanResultRow: View {
    let item: ScreenshotItem

    var body: some View {
        let result = item.result
        VStack(alignment: .leading, spacing: 2) {
            Text(result?.title ?? item.assetID)
                .font(.body)
            Text(details(result))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func details(_ result: ActionResult?) -> String {
        guard let result else { return item.status.rawValue }
        var parts = [result.date, result.time, result.location].compactMap(\.self)
        if let amount = result.amount {
            parts.append("\(amount) \(result.currency?.rawValue ?? "")")
        }
        parts.append(result.confidence.rawValue)
        return parts.joined(separator: " · ")
    }
}
