import SwiftUI

/// Small label saying why a screenshot is offered for deletion ("Blurry", "Duplicate", "Not useful").
struct CleanupReasonBadge: View {
    let reason: CleanupReason

    var body: some View {
        Label(Self.label(reason), systemImage: Self.systemImage(reason))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
    }

    static func label(_ reason: CleanupReason) -> String {
        switch reason {
        case .blurry: "Blurry"
        case .duplicate: "Duplicate"
        case .notUseful: "Not useful"
        }
    }

    static func systemImage(_ reason: CleanupReason) -> String {
        switch reason {
        case .blurry: "aqi.low"
        case .duplicate: "square.on.square"
        case .notUseful: "hand.thumbsdown"
        }
    }
}
