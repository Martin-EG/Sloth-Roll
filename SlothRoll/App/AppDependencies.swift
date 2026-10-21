/// Composition root: builds the live services once and hands them to features.
@MainActor
final class AppDependencies {
    static let live = AppDependencies(vlm: VLMService())

    let vlm: any VLMServing

    init(vlm: any VLMServing) {
        self.vlm = vlm
    }
}
