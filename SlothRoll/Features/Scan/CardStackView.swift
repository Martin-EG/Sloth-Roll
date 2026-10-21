import SwiftData
import SwiftUI

/// Stack of results waiting for review, newest first. Swipe right (or tap the action button)
/// to run the action, left (or Skip) to skip; tap a card to fix it first.
struct CardStackView: View {
    @Bindable var viewModel: CardStackViewModel

    @Query private var items: [ScreenshotItem]
    @State private var drag: CGSize = .zero
    @State private var editing: ScreenshotItem?

    init(viewModel: CardStackViewModel) {
        self.viewModel = viewModel
        let extracted = ScanStatus.extracted.rawValue
        _items = Query(
            filter: #Predicate { $0.statusRaw == extracted },
            sort: \.capturedAt, order: .reverse)
    }

    private var queue: [ScreenshotItem] { items.filter { $0.result != nil } }

    var body: some View {
        Group {
            if let top = queue.first {
                VStack(spacing: 20) {
                    stack
                    buttons(for: top)
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Nothing to do. Very sloth.", systemImage: "leaf",
                    description: Text("Tap Scan to look for new screenshots."))
            }
        }
        .toast($viewModel.toast, duration: ScanConfig.toastDuration)
        .sheet(item: $editing) { item in
            if let result = item.result {
                EditSheet(result: result) { viewModel.save($0, for: item) }
            }
        }
    }

    private var stack: some View {
        let visible = Array(queue.prefix(ScanConfig.visibleCards).enumerated())
        return GeometryReader { geometry in
            ZStack {
                ForEach(visible.reversed(), id: \.element.assetID) { index, item in
                    let isTop = index == 0
                    CardView(item: item, viewModel: viewModel)
                        .overlay { if isTop { tint } }
                        .clipShape(RoundedRectangle(cornerRadius: ScanConfig.cardCornerRadius))
                        .scaleEffect(1 - CGFloat(index) * ScanConfig.stackScaleStep, anchor: .bottom)
                        .offset(y: CGFloat(index) * ScanConfig.stackOffsetStep)
                        .offset(isTop ? drag : .zero)
                        .rotationEffect(isTop ? rotation(width: geometry.size.width) : .zero)
                        .allowsHitTesting(isTop && !viewModel.isPerforming)
                        .accessibilityHidden(!isTop)
                        .onTapGesture { editing = item }
                        .gesture(dragGesture(for: item))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Opens the editor. Swipe right to do it, left to skip.")
                        .accessibilityActions {
                            Button(CardText.actionName(item.result?.type ?? .none)) {
                                commit(item, accept: true)
                            }
                            Button("Skip") { commit(item, accept: false) }
                        }
                }
            }
        }
    }

    private func buttons(for item: ScreenshotItem) -> some View {
        HStack(spacing: 16) {
            Button {
                commit(item, accept: false)
            } label: {
                Label("Skip", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                commit(item, accept: true)
            } label: {
                Label(CardText.actionName(item.result?.type ?? .none), systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .controlSize(.large)
        .disabled(viewModel.isPerforming)
    }

    /// Green toward "do it", red toward "skip", strongest at the swipe threshold.
    private var tint: some View {
        let progress = min(abs(drag.width) / ScanConfig.swipeThreshold, 1)
        return (drag.width > 0 ? Color.green : Color.red)
            .opacity(progress * ScanConfig.maxTintOpacity)
            .allowsHitTesting(false)
    }

    private func rotation(width: CGFloat) -> Angle {
        .degrees(Double(drag.width / max(width, 1)) * ScanConfig.maxRotationDegrees)
    }

    private func dragGesture(for item: ScreenshotItem) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > ScanConfig.swipeThreshold {
                    commit(item, accept: value.translation.width > 0)
                } else {
                    withAnimation(.spring) { drag = .zero }
                }
            }
    }

    /// Flies the card off, then runs or skips it. A failed action springs the card back.
    private func commit(_ item: ScreenshotItem, accept: Bool) {
        guard !viewModel.isPerforming else { return }
        let direction: CGFloat = accept ? 1 : -1
        withAnimation(.easeIn(duration: ScanConfig.flyOutSeconds)) {
            drag = CGSize(width: direction * ScanConfig.flyOutDistance, height: drag.height)
        }
        Task {
            let left = accept ? await viewModel.perform(item) : viewModel.skip(item)
            if left {
                // The next card takes the top spot already centered, not flying back in.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { drag = .zero }
            } else {
                withAnimation(.spring) { drag = .zero }
            }
        }
    }
}
