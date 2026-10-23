import SwiftData
import SwiftUI

/// Scan tab: a Scan button with live progress on top, the review card stack below. Shows a
/// full-screen prompt instead when Photos access is off.
struct ScanView: View {
    @Bindable var viewModel: ScanViewModel
    let cardStackViewModel: CardStackViewModel

    @AppStorage(SettingsKey.scanLimit) private var scanLimit = PipelineConfig.scanLimit
    @AppStorage(SettingsKey.scanAlbumID) private var albumID = ""
    @AppStorage(SettingsKey.scanAlbumTitle) private var albumTitle = ""
    @State private var isPickingAlbum = false

    var body: some View {
        Group {
            if viewModel.hasNoPhotoAccess {
                noPhotoAccess
            } else {
                VStack(spacing: 0) {
                    scanHeader
                        .padding(.horizontal)
                        .padding(.top, 8)
                    CardStackView(viewModel: cardStackViewModel, isScanning: viewModel.isRunning)
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Sloth Roll")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickingAlbum) {
            AlbumPickerView(viewModel: viewModel, albumID: $albumID, albumTitle: $albumTitle)
        }
        #if DEBUG
        .task {
            await viewModel.autorunIfRequested(
                limit: scanLimit, albumID: albumID.isEmpty ? nil : albumID)
        }
        #endif
    }

    private func startScan() {
        Task {
            // Drops a saved album that was deleted in Photos since it was picked.
            if !albumID.isEmpty { await viewModel.loadAlbums() }
            let source = viewModel.validAlbumID(albumID)
            if source == nil, !albumID.isEmpty {
                albumID = ""
                albumTitle = ""
            }
            await viewModel.scan(limit: scanLimit, albumID: source)
        }
    }

    /// "Scan from: All recent photos ›" — opens the album picker.
    private var sourceButton: some View {
        Button {
            isPickingAlbum = true
        } label: {
            HStack {
                Label(
                    ScanViewModel.sourceLabel(albumTitle: albumTitle),
                    systemImage: albumID.isEmpty ? "photo.on.rectangle" : "rectangle.stack")
                Spacer()
                Text("Change")
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
            .font(.subheadline)
        }
        .accessibilityLabel("Scan from \(ScanViewModel.sourceLabel(albumTitle: albumTitle))")
        .accessibilityHint("Pick an album to scan")
    }

    private var noPhotoAccess: some View {
        ContentUnavailableView {
            Label("Photos access is off", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("Sloth Roll reads your screenshots on this iPhone to find events, places, and receipts. Turn on Photos access in Settings.")
        } actions: {
            Button("Open Settings") { viewModel.openSettings() }
                .buttonStyle(.borderedProminent)
            Button("Check again", action: startScan)
        }
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
                sourceButton
                Button(action: startScan) {
                    Label(viewModel.scanButtonTitle, systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(viewModel.isStatusWarning ? Color.orange : Color.secondary)
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
                .clipShape(RoundedRectangle(cornerRadius: ScanConfig.thumbnailCornerRadius))
        } else {
            RoundedRectangle(cornerRadius: ScanConfig.thumbnailCornerRadius)
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
        triage: Triage(), analyzer: ImageAnalyzer(), modelContext: container.mainContext)
    let cards = CardStackViewModel(
        performers: [:], photoLibrary: library, context: container.mainContext)
    NavigationStack {
        ScanView(
            viewModel: ScanViewModel(coordinator: coordinator, photoLibrary: library),
            cardStackViewModel: cards)
    }
    .modelContainer(container)
}
#endif
