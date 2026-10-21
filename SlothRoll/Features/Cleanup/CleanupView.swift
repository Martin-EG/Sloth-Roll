import SwiftData
import SwiftUI

/// Grid of skipped screenshots worth deleting (blurry, duplicate, or not useful), all selected
/// by default, with one button that moves the selection to Recently Deleted.
struct CleanupView: View {
    @Bindable var viewModel: CleanupViewModel

    @Query(
        filter: #Predicate<ScreenshotItem> { $0.cleanupReasonRaw != nil },
        sort: \ScreenshotItem.capturedAt, order: .reverse)
    private var candidates: [ScreenshotItem]

    var body: some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView(
                    "All clean", systemImage: "sparkles",
                    description: Text(
                        "Blurry, duplicate, and useless screenshots show up here after a scan."))
            } else {
                grid
            }
        }
        .navigationTitle("Clean up")
        .toolbar {
            if !candidates.isEmpty {
                Button(viewModel.allSelected(in: candidates) ? "Deselect all" : "Select all") {
                    viewModel.toggleAll(in: candidates)
                }
            }
        }
        .toast($viewModel.toast, duration: CleanupConfig.toastDuration)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: CleanupConfig.gridMinCellWidth),
                        spacing: CleanupConfig.gridSpacing)
                ],
                spacing: CleanupConfig.gridSpacing
            ) {
                ForEach(candidates) { item in
                    CleanupCell(item: item, viewModel: viewModel)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            deleteBar
        }
    }

    private var deleteBar: some View {
        let count = viewModel.selectedCount(in: candidates)
        return VStack(spacing: 6) {
            Button(role: .destructive) {
                Task { await viewModel.deleteSelected(from: candidates) }
            } label: {
                Text(viewModel.deleteButtonTitle(count: count))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(count == 0 || viewModel.isDeleting)
            Text("Photos asks first. Deleted screenshots stay in Recently Deleted for 30 days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.bar)
    }
}

#if DEBUG
#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    for (index, reason) in CleanupReason.allCases.enumerated() {
        let item = ScreenshotItem(
            assetID: "preview-\(index)", status: .skipped, skipReason: .littleText,
            capturedAt: .now)
        item.cleanupReason = reason
        container.mainContext.insert(item)
    }
    return NavigationStack {
        CleanupView(
            viewModel: CleanupViewModel(
                photoLibrary: PreviewPhotoLibrary(), context: container.mainContext))
    }
    .modelContainer(container)
}
#endif
