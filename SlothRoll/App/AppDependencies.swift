/// Composition root: builds the live services once and hands them to features.
@MainActor
final class AppDependencies {
    static let live = AppDependencies(vlm: VLMService(), photoLibrary: PhotoLibrary())

    let vlm: any VLMServing
    let photoLibrary: any PhotoLibraryProviding

    init(vlm: any VLMServing, photoLibrary: any PhotoLibraryProviding) {
        self.vlm = vlm
        self.photoLibrary = photoLibrary
    }
}
