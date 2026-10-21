import SwiftUI

/// Last onboarding screen: the one-time model download with its size, a progress bar,
/// retry on failure, and a Start button once it's on the phone.
struct ModelDownloadView: View {
    let viewModel: OnboardingViewModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: OnboardingConfig.pageSpacing) {
            Spacer()
            Image(systemName: heroSymbol)
                .font(.system(size: OnboardingConfig.heroSymbolSize))
                .foregroundStyle(.tint)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            Text("Get the reading model")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text("A one-time \(viewModel.downloadSizeText) download. After this, Sloth Roll works offline.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Label("Wi-Fi recommended", systemImage: "wifi")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            status
                .frame(minHeight: 60)
            Spacer()
        }
        .padding(.horizontal, 32)
        .animation(.default, value: viewModel.state)
        .task { await viewModel.checkExistingDownload() }
    }

    private var heroSymbol: String {
        viewModel.state == .done ? "checkmark.circle.fill" : "arrow.down.circle"
    }

    @ViewBuilder private var status: some View {
        switch viewModel.state {
        case .checking:
            ProgressView()
        case .idle:
            primaryButton("Download (\(viewModel.downloadSizeText))", systemImage: "arrow.down") {
                Task { await viewModel.download() }
            }
        case .downloading(let fraction):
            VStack(spacing: 8) {
                ProgressView(value: fraction) {
                    Text("Downloading…")
                } currentValueLabel: {
                    Text(viewModel.progressText ?? "")
                        .monospacedDigit()
                }
                Text("Keep Sloth Roll open until it finishes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                primaryButton("Retry", systemImage: "arrow.clockwise") {
                    Task { await viewModel.download() }
                }
            }
        case .done:
            primaryButton("Start", systemImage: "arrow.right", action: onFinish)
        }
    }

    private func primaryButton(
        _ title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
