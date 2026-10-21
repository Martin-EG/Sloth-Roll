#if DEBUG
import SwiftUI

/// One eval row: thumbnail, decoded fields, timings, and a menu to mark it right or wrong.
struct EvalRowView: View {
    let row: EvalRow
    let onMark: (EvalMark?) -> Void

    private var result: ActionResult { row.report.result }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.type.rawValue.uppercased())
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: .capsule)
                    Text(result.confidence.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    markMenu
                }
                Text(result.title).font(.subheadline.bold())
                if let details { Text(details).font(.caption) }
                Text(timings)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(row.report.usedFallback ? .red : .secondary)
                DisclosureGroup("Raw output") {
                    Text(row.report.rawOutputs.joined(separator: "\n---\n"))
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
                .font(.caption2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = row.thumbnail {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: EvalConfig.thumbnailSize.width, height: EvalConfig.thumbnailSize.height)
                .clipShape(.rect(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: EvalConfig.thumbnailSize.width, height: EvalConfig.thumbnailSize.height)
        }
    }

    private var markMenu: some View {
        Menu {
            Button("Correct", systemImage: "checkmark") { onMark(.correct) }
            Menu("Wrong, should be…") {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Button(type.rawValue) { onMark(.wrong(expected: type)) }
                }
            }
            if row.mark != nil {
                Button("Clear mark", systemImage: "xmark.circle", role: .destructive) { onMark(nil) }
            }
        } label: {
            switch row.mark {
            case .correct:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .wrong(let expected):
                Label(expected.rawValue, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            case nil:
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Mark result")
    }

    /// "2026-10-24 21:00 · Blue Room · 249.50 MXN", or nil if every field is empty.
    private var details: String? {
        let amount = result.amount.map { amount in
            [amount.formatted(.number.precision(.fractionLength(2))), result.currency?.rawValue]
                .compactMap(\.self).joined(separator: " ")
        }
        let when = [result.date, result.time].compactMap(\.self).joined(separator: " ")
        let parts = [when.isEmpty ? nil : when, result.location, amount].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var timings: String {
        var parts = [
            "VLM \(seconds(row.report.duration))",
            "OCR \(seconds(row.textScan.duration))",
            "\(row.textScan.characterCount) chars",
            row.source.rawValue,
        ]
        if row.report.attempts > 1 { parts.append("retried") }
        if row.report.usedFallback { parts.append("fallback") }
        return parts.joined(separator: " · ")
    }

    private func seconds(_ duration: Duration) -> String {
        duration.seconds.formatted(.number.precision(.fractionLength(2))) + " s"
    }
}
#endif
