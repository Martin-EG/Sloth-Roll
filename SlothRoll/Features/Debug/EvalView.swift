#if DEBUG
import SwiftUI

/// Debug screen: runs the extractor over the "Sloth Test" album and shows per-image results,
/// a summary, and right/wrong marks for computing accuracy.
struct EvalView: View {
    @Bindable var viewModel: EvalViewModel

    var body: some View {
        NavigationStack {
            List {
                modelSection
                runSection
                if !viewModel.rows.isEmpty {
                    summarySection
                    resultsSection
                }
            }
            .navigationTitle("Eval")
            .task { await viewModel.autorunIfRequested() }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            Text(viewModel.modelID)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            if viewModel.phase == .loadingModel {
                ProgressView(value: viewModel.downloadProgress) {
                    Text("Downloading and loading…")
                } currentValueLabel: {
                    Text(viewModel.downloadProgress, format: .percent.precision(.fractionLength(0)))
                }
            }

            if viewModel.isModelLoaded {
                Button("Unload model", role: .destructive) {
                    Task { await viewModel.unloadModel() }
                }
                .disabled(viewModel.phase == .running)
            } else {
                Button("Load model") {
                    Task { await viewModel.loadModel() }
                }
                .disabled(viewModel.phase == .loadingModel)
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
    }

    private var runSection: some View {
        Section("Album “\(EvalConfig.albumName)”") {
            if viewModel.phase == .running {
                ProgressView(
                    value: Double(viewModel.progress.done),
                    total: Double(max(viewModel.progress.total, 1))
                ) {
                    Text("Reading \(viewModel.progress.done + 1) of \(viewModel.progress.total)…")
                }
                Button("Stop after this image", role: .cancel) { viewModel.cancel() }
            } else {
                Button("Run eval") {
                    Task { await viewModel.run() }
                }
                .disabled(viewModel.phase != .ready)
            }
            if !viewModel.skippedAssetIDs.isEmpty {
                Text("\(viewModel.skippedAssetIDs.count) images skipped (not on device).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summarySection: some View {
        let summary = viewModel.summary
        return Section("Summary") {
            LabeledContent("Images", value: "\(summary.total)")
            LabeledContent("Per type", value: typeCounts(summary))
            LabeledContent("Avg extraction", value: seconds(summary.averageExtraction))
            LabeledContent("Avg OCR", value: seconds(summary.averageOCR))
            LabeledContent(
                "Retries / fallbacks", value: "\(summary.retryCount) / \(summary.fallbackCount)")
            LabeledContent("Accuracy", value: accuracy(summary))
            LabeledContent("No text (OCR)", value: "\(summary.noTextCount)")
            LabeledContent(
                "Junk dropped by no-text",
                value: "\(summary.junkWithoutText) of \(summary.markedJunkCount) marked")
            LabeledContent("Real actions lost", value: "\(summary.actionableWithoutText)")
        }
        .monospacedDigit()
    }

    private var resultsSection: some View {
        Section("Results") {
            ForEach(viewModel.rows) { row in
                EvalRowView(row: row) { mark in
                    viewModel.setMark(mark, for: row.id)
                }
            }
        }
    }

    private func typeCounts(_ summary: EvalSummary) -> String {
        ActionType.allCases
            .map { "\($0.rawValue) \(summary.countsByType[$0, default: 0])" }
            .joined(separator: " · ")
    }

    private func accuracy(_ summary: EvalSummary) -> String {
        guard let accuracy = summary.accuracy else { return "mark rows below" }
        let percent = accuracy.formatted(.percent.precision(.fractionLength(0)))
        return "\(summary.correctCount)/\(summary.markedCount) (\(percent))"
    }

    private func seconds(_ duration: Duration?) -> String {
        guard let duration else { return "—" }
        return duration.seconds.formatted(.number.precision(.fractionLength(2))) + " s"
    }
}

#Preview("Ran") {
    @Previewable @State var viewModel = EvalViewModel(
        vlm: PreviewVLM(delay: .milliseconds(50)), photoLibrary: PreviewPhotoLibrary())
    EvalView(viewModel: viewModel)
        .task {
            await viewModel.loadModel()
            await viewModel.run()
        }
}

#Preview("Idle") {
    EvalView(viewModel: EvalViewModel(vlm: PreviewVLM(), photoLibrary: PreviewPhotoLibrary()))
}
#endif
