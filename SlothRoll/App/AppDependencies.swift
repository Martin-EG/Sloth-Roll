import SwiftData

/// Composition root: builds the live services once and hands them to features.
@MainActor
final class AppDependencies {
    static let live = AppDependencies(
        vlm: VLMService(), photoLibrary: PhotoLibrary(), triage: Triage(),
        analyzer: ImageAnalyzer(), modelContainer: Persistence.makeContainer())

    let vlm: any VLMServing
    let photoLibrary: any PhotoLibraryProviding
    let modelContainer: ModelContainer
    let scanCoordinator: ScanCoordinator
    /// One performer per action type; "none" has none.
    let actionPerformers: [ActionType: any ActionPerformer]

    /// `actionPerformers` defaults to the live EventKit / Maps / SwiftData ones.
    init(
        vlm: any VLMServing, photoLibrary: any PhotoLibraryProviding,
        triage: any ImageTriaging, analyzer: any ImageAnalyzing, modelContainer: ModelContainer,
        actionPerformers: [ActionType: any ActionPerformer]? = nil
    ) {
        self.vlm = vlm
        self.photoLibrary = photoLibrary
        self.modelContainer = modelContainer
        self.scanCoordinator = ScanCoordinator(
            vlm: vlm, photoLibrary: photoLibrary, triage: triage, analyzer: analyzer,
            modelContext: modelContainer.mainContext)
        self.actionPerformers =
            actionPerformers ?? [
                .event: EventAction(),
                .place: PlaceAction(),
                .receipt: ReceiptAction(context: modelContainer.mainContext),
            ]
    }
}
