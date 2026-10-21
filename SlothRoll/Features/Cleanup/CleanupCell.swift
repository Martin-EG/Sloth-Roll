import SwiftUI

/// One grid cell: the screenshot, its reason badge, and a selection checkmark. Tap toggles.
struct CleanupCell: View {
    let item: ScreenshotItem
    let viewModel: CleanupViewModel

    @State private var image: CGImage?

    var body: some View {
        let isSelected = viewModel.isSelected(item)
        Button {
            viewModel.toggle(item)
        } label: {
            Color(.secondarySystemBackground)
                .aspectRatio(CleanupConfig.cellAspectRatio, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CleanupConfig.cellCornerRadius))
                .opacity(isSelected ? 1 : CleanupConfig.unselectedOpacity)
                .overlay(alignment: .bottomLeading) {
                    if let reason = item.cleanupReason {
                        CleanupReasonBadge(reason: reason).padding(4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? Color.accentColor : .black.opacity(0.3))
                        .padding(6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: item.assetID) {
            image = await viewModel.thumbnail(for: item.assetID)
        }
    }

    private var accessibilityText: String {
        let reason = item.cleanupReason.map(CleanupReasonBadge.label) ?? ""
        guard let date = item.capturedAt else { return "Screenshot, \(reason)" }
        return "Screenshot from \(date.formatted(date: .abbreviated, time: .omitted)), \(reason)"
    }
}
