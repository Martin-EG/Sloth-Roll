import SwiftData

/// Composition root: builds the live services once and hands them to features.
@MainActor
final class AppDependencies {
    static let live = AppDependencies(
        vlm: VLMService(), photoLibrary: PhotoLibrary(), triage: Triage(),
        modelContainer: Persistence.makeContainer())

    let vlm: any VLMServing
    let photoLibrary: any PhotoLibraryProviding
    let modelContainer: ModelContainer
    let scanCoordinator: ScanCoordinator

    init(
        vlm: any VLMServing, photoLibrary: any PhotoLibraryProviding,
        triage: any ImageTriaging, modelContainer: ModelContainer
    ) {
        self.vlm = vlm
        self.photoLibrary = photoLibrary
        self.modelContainer = modelContainer
        self.scanCoordinator = ScanCoordinator(
            vlm: vlm, photoLibrary: photoLibrary, triage: triage,
            modelContext: modelContainer.mainContext)
    }
}
