import SwiftUI

/// Top-level screen switcher. Day 2: shows the extraction eval screen in debug builds.
struct RootView: View {
    let dependencies: AppDependencies

    #if DEBUG
    @State private var evalViewModel: EvalViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _evalViewModel = State(
            initialValue: EvalViewModel(
                vlm: dependencies.vlm, photoLibrary: dependencies.photoLibrary))
    }
    #endif

    var body: some View {
        #if DEBUG
        EvalView(viewModel: evalViewModel)
        #else
        ContentUnavailableView("Sloth Roll", systemImage: "photo.stack", description: Text("Coming soon."))
        #endif
    }
}

#if DEBUG
#Preview {
    RootView(dependencies: AppDependencies(vlm: PreviewVLM(), photoLibrary: PreviewPhotoLibrary()))
}
#endif
