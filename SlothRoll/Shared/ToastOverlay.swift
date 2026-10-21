import SwiftUI

/// Shows a `Toast` at the bottom of the view and clears it after `duration`.
struct ToastOverlay: ViewModifier {
    @Binding var toast: Toast?
    let duration: Duration

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                Label(toast.message, systemImage: toast.isError ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(toast.isError ? Color.orange : Color.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: duration)
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.spring, value: toast)
        .onChange(of: toast) { _, new in
            if let new {
                AccessibilityNotification.Announcement(new.message).post()
            }
        }
    }
}

extension View {
    /// Overlays `toast` at the bottom and dismisses it after `duration`.
    func toast(_ toast: Binding<Toast?>, duration: Duration) -> some View {
        modifier(ToastOverlay(toast: toast, duration: duration))
    }
}
