import SwiftUI

/// First-launch screens: what the app does, the privacy promise, scanning one album and
/// cleaning it up, then the model download.
/// `onFinish` runs once the model is on the phone and the user taps Start.
struct OnboardingView: View {
    let viewModel: OnboardingViewModel
    let onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            OnboardingPage(
                title: "You take screenshots. Sloth Roll does the rest.",
                text: "Events go to your calendar, places open in Maps, receipts become expenses. You just swipe."
            ) {
                Image("SlothMark")
                    .resizable()
                    .frame(width: OnboardingConfig.logoSize, height: OnboardingConfig.logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: OnboardingConfig.logoCornerRadius))
                    .accessibilityHidden(true)
            }
            .tag(0)

            OnboardingPage(
                title: "Everything runs on your iPhone. Nothing is uploaded.",
                text: "The model reads your screenshots right here on the phone, even in airplane mode."
            ) {
                Image(systemName: "lock.iphone")
                    .font(.system(size: OnboardingConfig.heroSymbolSize))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .tag(1)

            OnboardingPage(
                title: "Scan one album, then clean it up.",
                text: "Keep your screenshots in an album? Pick it before you scan. Swipe through what's useful, then delete the blurry, duplicate, and useless ones in one tap. They go to Recently Deleted."
            ) {
                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: OnboardingConfig.heroSymbolSize))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .tag(2)

            ModelDownloadView(viewModel: viewModel, onFinish: onFinish)
                .tag(OnboardingConfig.downloadPage)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .safeAreaInset(edge: .bottom) {
            if page < OnboardingConfig.downloadPage {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom)
            }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingView(viewModel: OnboardingViewModel(vlm: PreviewVLM(delay: .seconds(3)))) {}
}

#Preview("Download fails") {
    OnboardingView(viewModel: OnboardingViewModel(vlm: PreviewVLM(failLoad: true))) {}
}
#endif
