import SwiftUI

/// One intro page: a big picture, a headline, and a line of plain text.
struct OnboardingPage<Hero: View>: View {
    let title: String
    let text: String
    @ViewBuilder let hero: Hero

    var body: some View {
        VStack(spacing: OnboardingConfig.pageSpacing) {
            Spacer()
            hero
            Text(title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
    }
}
