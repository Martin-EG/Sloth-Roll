import SwiftUI

/// Top-level screen: the scan screen, with a debug menu (eval screen, cache reset) in debug
/// builds.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var scanViewModel: ScanViewModel
    #if DEBUG
    @State private var evalViewModel: EvalViewModel
    @State private var isShowingEval = false
    #endif

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _scanViewModel = State(initialValue: ScanViewModel(coordinator: dependencies.scanCoordinator))
        #if DEBUG
        _evalViewModel = State(
            initialValue: EvalViewModel(
                vlm: dependencies.vlm, photoLibrary: dependencies.photoLibrary))
        #endif
    }

    var body: some View {
        NavigationStack {
            ScanView(viewModel: scanViewModel)
                #if DEBUG
                .toolbar { debugMenu }
                #endif
        }
        #if DEBUG
        .sheet(isPresented: $isShowingEval) {
            EvalView(viewModel: evalViewModel)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains(EvalConfig.autorunArgument) {
                isShowingEval = true
            }
        }
        #endif
    }

    #if DEBUG
    private var debugMenu: some View {
        Menu("Debug", systemImage: "ladybug") {
            Button("Eval screen", systemImage: "checklist") { isShowingEval = true }
            Button("Clear scan cache", systemImage: "trash", role: .destructive) {
                scanViewModel.resetCache()
            }
            .disabled(scanViewModel.isRunning)
        }
    }
    #endif
}

#if DEBUG
#Preview {
    let dependencies = AppDependencies(
        vlm: PreviewVLM(), photoLibrary: PreviewPhotoLibrary(), triage: Triage(),
        modelContainer: Persistence.makeContainer(inMemory: true))
    RootView(dependencies: dependencies)
        .modelContainer(dependencies.modelContainer)
}
#endif
