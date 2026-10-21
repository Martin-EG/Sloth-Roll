import PhotosUI
import SwiftUI

/// Temporary day-1 screen proving on-device VLM inference: load, pick, describe, show metrics.
struct SpikeView: View {
    @Bindable var viewModel: SpikeViewModel
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                modelSection
                imageSection
                outputSection
                metricsSection
            }
            .navigationTitle("Model spike")
            .onChange(of: pickerItem) { _, item in
                Task { await viewModel.select(item) }
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            Text(viewModel.modelID)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            if viewModel.phase == .loading {
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
                .disabled(viewModel.phase == .describing)
            } else {
                Button("Load model") {
                    Task { await viewModel.loadModel() }
                }
                .disabled(viewModel.phase == .loading)
            }
        }
    }

    private var imageSection: some View {
        Section("Screenshot") {
            PhotosPicker("Pick image", selection: $pickerItem, matching: .images)

            if let image = viewModel.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
            }

            Button {
                Task { await viewModel.describe() }
            } label: {
                if viewModel.phase == .describing {
                    HStack {
                        ProgressView()
                        Text("Describing…")
                    }
                } else {
                    Text("Describe")
                }
            }
            .disabled(!viewModel.canDescribe)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        if let output = viewModel.output {
            Section("Output") {
                Text(output).textSelection(.enabled)
            }
        }
        if let error = viewModel.errorMessage {
            Section {
                Text(error).foregroundStyle(.red)
            }
        }
    }

    private var metricsSection: some View {
        Section("Metrics") {
            metricRow("Load time", viewModel.loadTime.map(formatSeconds))
            metricRow("Inference time", viewModel.inferenceTime.map(formatSeconds))
            metricRow("Peak memory (last run)", viewModel.runPeakBytes.map(formatBytes))
            metricRow("Peak memory (since launch)", viewModel.lifetimePeakBytes.map(formatBytes))
            metricRow("Available memory", viewModel.availableBytes.map(formatBytes))
            metricRow("Describes this session", String(viewModel.describeCount))
        }
    }

    private func metricRow(_ title: String, _ value: String?) -> some View {
        LabeledContent(title, value: value ?? "—")
            .monospacedDigit()
    }

    private func formatSeconds(_ duration: Duration) -> String {
        duration.seconds.formatted(.number.precision(.fractionLength(2))) + " s"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        Int64(clamping: bytes).formatted(SpikeConfig.byteFormat)
    }
}

#if DEBUG
#Preview("Idle") {
    SpikeView(viewModel: SpikeViewModel(vlm: PreviewVLM()))
}

#Preview("Loading") {
    @Previewable @State var viewModel = SpikeViewModel(vlm: PreviewVLM(delay: .seconds(60)))
    SpikeView(viewModel: viewModel)
        .task { await viewModel.loadModel() }
}

#Preview("Described") {
    @Previewable @State var viewModel = SpikeViewModel(vlm: PreviewVLM())
    SpikeView(viewModel: viewModel)
        .task {
            await viewModel.loadModel()
            if let image = PreviewVLM.sampleImage() {
                viewModel.setImageForPreview(image)
            }
            await viewModel.describe()
        }
}

#Preview("Load failed") {
    @Previewable @State var viewModel = SpikeViewModel(vlm: PreviewVLM(failLoad: true))
    SpikeView(viewModel: viewModel)
        .task { await viewModel.loadModel() }
}
#endif
