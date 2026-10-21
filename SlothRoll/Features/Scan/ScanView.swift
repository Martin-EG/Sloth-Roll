import SwiftData
import SwiftUI

/// Scan tab: a Scan button with live progress on top, the review card stack below.
struct ScanView: View {
    @Bindable var viewModel: ScanViewModel
    let cardStackViewModel: CardStackViewModel

    var body: some View {
        VStack(spacing: 0) {
            scanHeader
                .padding(.horizontal)
                .padding(.top, 8)
            CardStackView(viewModel: cardStackViewModel)
                .frame(maxHeight: .infinity)
        }
        .navigationTitle("Sloth Roll")
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .task { await viewModel.autorunIfRequested() }
        #endif
    }

    private var scanHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    .font(.footnote)
            } else {
                Button {
                    Task { await viewModel.scan() }
                } label: {
                    Label(viewModel.scanButtonTitle, systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
    let library = PreviewPhotoLibrary()
    let coordinator = ScanCoordinator(
        vlm: PreviewVLM(delay: .milliseconds(300)), photoLibrary: library,
        triage: Triage(), modelContext: container.mainContext)
    let cards = CardStackViewModel(
        performers: [:], photoLibrary: library, context: container.mainContext)
    NavigationStack {
        ScanView(viewModel: ScanViewModel(coordinator: coordinator), cardStackViewModel: cards)
    }
    .modelContainer(container)
}
#endif
