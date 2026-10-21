import SwiftUI

/// Top-level screen switcher. Day 1: shows the model spike in debug builds.
struct RootView: View {
    let dependencies: AppDependencies

    #if DEBUG
    @State private var spikeViewModel: SpikeViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _spikeViewModel = State(initialValue: SpikeViewModel(vlm: dependencies.vlm))
    }
    #endif

    var body: some View {
        #if DEBUG
        SpikeView(viewModel: spikeViewModel)
        #else
        ContentUnavailableView("Sloth Roll", systemImage: "photo.stack", description: Text("Coming soon."))
        #endif
    }
}

#if DEBUG
#Preview {
    RootView(dependencies: AppDependencies(vlm: PreviewVLM()))
}
#endif
