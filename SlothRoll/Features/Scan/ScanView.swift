import SwiftData
import SwiftUI

/// Scan screen: a Scan button, live progress from the coordinator, and (temporarily) the
/// stored results grouped by type, to check the pipeline before the swipe UI exists.
struct ScanView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        List {
            scanSection
            if let stats = viewModel.stats, !viewModel.isRunning {
                ScanStatsSection(stats: stats)
            }
            ScanResultsSections()
        }
        .navigationTitle("Sloth Roll")
        #if DEBUG
        .task { await viewModel.autorunIfRequested() }
        #endif
    }

    private var scanSection: some View {
        Section {
            if viewModel.isRunning {
                HStack(alignment: .center, spacing: 12) {
                    thumbnail
                    ProgressView(
                        value: Double(viewModel.progress.done),
                        total: Double(max(viewModel.progress.total, 1))
                    ) {
                        Text(viewModel.progressLabel)
                    } currentValueLabel: {
                        Text("\(viewModel.progress.done) / \(viewModel.progress.total)")
                            .monospacedDigit()
                    }
                }
                Button("Stop after this one", role: .cancel) { viewModel.cancel() }
            } else {
                Button(viewModel.scanButtonTitle) {
                    Task { await viewModel.scan() }
                }
            }
            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(viewModel.phase == .finished ? Color.secondary : Color.orange)
            }
            if viewModel.isLimitedAccess {
                Text("Sloth Roll can only see the photos you picked. To scan all screenshots, allow full access in Settings › Privacy › Photos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = viewModel.currentThumbnail {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: ScanConfig.thumbnailSize.width, height: ScanConfig.thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: ScanConfig.thumbnailSize.width, height: ScanConfig.thumbnailSize.height)
        }
    }
}

#if DEBUG
#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    let coordinator = ScanCoordinator(
        vlm: PreviewVLM(delay: .milliseconds(300)), photoLibrary: PreviewPhotoLibrary(),
        triage: Triage(), modelContext: container.mainContext)
    NavigationStack {
        ScanView(viewModel: ScanViewModel(coordinator: coordinator))
    }
    .modelContainer(container)
}
#endif
