import SwiftUI

/// Icon and label for an action type ("Event", "Place", "Receipt").
struct TypeBadge: View {
    let type: ActionType

    var body: some View {
        Label(CardText.typeLabel(type), systemImage: CardText.systemImage(type))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }
}
