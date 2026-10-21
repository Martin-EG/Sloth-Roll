import SwiftUI

/// One review card: the screenshot, its type, the title, and the proposed action in plain words.
struct CardView: View {
    let item: ScreenshotItem
    let viewModel: CardStackViewModel

    @State private var image: CGImage?

    var body: some View {
        let result = item.result
        VStack(alignment: .leading, spacing: 0) {
            screenshot
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let result { TypeBadge(type: result.type) }
                    Spacer()
                    if result?.confidence == .low { notSureTag }
                }
                Text(result?.title ?? "")
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                if let result {
                    Text(CardText.proposal(result))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: ScanConfig.cardCornerRadius))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .task(id: item.assetID) {
            image = await viewModel.preview(for: item.assetID)
        }
    }

    private var screenshot: some View {
        Color(.tertiarySystemBackground)
            .overlay(alignment: .top) {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var notSureTag: some View {
        Text("not sure")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(.secondary.opacity(0.5)))
            .accessibilityLabel("The app is not sure about this one")
    }
}
