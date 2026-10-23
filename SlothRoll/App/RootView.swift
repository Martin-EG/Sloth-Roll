import SwiftData
import SwiftUI

/// First launch shows onboarding until the model is downloaded; after that, the tabs:
/// Scan (scan button + review cards), Expenses, Clean up (only while it has screenshots to
/// offer), and Settings.
struct RootView: View {
    let dependencies: AppDependencies

    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var onboardingViewModel: OnboardingViewModel
    @State private var scanViewModel: ScanViewModel
    @State private var cardStackViewModel: CardStackViewModel
    @State private var expensesViewModel: ExpensesViewModel
    @State private var cleanupViewModel: CleanupViewModel
    @State private var selectedTab = RootTab.scan
    @Query(filter: #Predicate<ScreenshotItem> { $0.cleanupReasonRaw != nil })
    private var cleanupCandidates: [ScreenshotItem]
    @State private var settingsViewModel: SettingsViewModel
    #if DEBUG
    @State private var evalViewModel: EvalViewModel
    @State private var isShowingEval = false
    #endif

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let context = dependencies.modelContainer.mainContext
        _onboardingViewModel = State(initialValue: OnboardingViewModel(vlm: dependencies.vlm))
        _scanViewModel = State(initialValue: ScanViewModel(
                coordinator: dependencies.scanCoordinator, photoLibrary: dependencies.photoLibrary))
        _cardStackViewModel = State(
            initialValue: CardStackViewModel(
                performers: dependencies.actionPerformers,
                photoLibrary: dependencies.photoLibrary, context: context))
        _expensesViewModel = State(initialValue: ExpensesViewModel(context: context))
        _cleanupViewModel = State(
            initialValue: CleanupViewModel(photoLibrary: dependencies.photoLibrary, context: context))
        _settingsViewModel = State(
            initialValue: SettingsViewModel(
                coordinator: dependencies.scanCoordinator, vlm: dependencies.vlm))
        #if DEBUG
        _evalViewModel = State(
            initialValue: EvalViewModel(
                vlm: dependencies.vlm, photoLibrary: dependencies.photoLibrary))
        #endif
    }

    var body: some View {
        if hasCompletedOnboarding || Self.skipsOnboarding {
            tabs
        } else {
            OnboardingView(viewModel: onboardingViewModel) {
                withAnimation { hasCompletedOnboarding = true }
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Scan", systemImage: "rectangle.stack", value: RootTab.scan) {
                NavigationStack {
                    ScanView(viewModel: scanViewModel, cardStackViewModel: cardStackViewModel)
                }
            }
            Tab("Expenses", systemImage: "creditcard", value: RootTab.expenses) {
                NavigationStack {
                    ExpenseListView(viewModel: expensesViewModel)
                }
            }
            // Stays while selected, so the "Moved to Recently Deleted" toast is seen even when
            // the last candidates were just deleted.
            if !cleanupCandidates.isEmpty || selectedTab == .cleanup {
                Tab("Clean up", systemImage: "sparkles", value: RootTab.cleanup) {
                    NavigationStack {
                        CleanupView(viewModel: cleanupViewModel)
                    }
                }
                .badge(cleanupCandidates.count)
            }
            Tab("Settings", systemImage: "gearshape", value: RootTab.settings) {
                NavigationStack {
                    #if DEBUG
                    SettingsView(viewModel: settingsViewModel) { isShowingEval = true }
                    #else
                    SettingsView(viewModel: settingsViewModel)
                    #endif
                }
            }
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

    /// Debug autorun launches (eval, timed scans) go straight to the tabs.
    private static var skipsOnboarding: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains(EvalConfig.autorunArgument)
            || arguments.contains(ScanConfig.autorunArgument)
        #else
        false
        #endif
    }
}

#if DEBUG
#Preview {
    let dependencies = AppDependencies(
        vlm: PreviewVLM(), photoLibrary: PreviewPhotoLibrary(), triage: Triage(),
        analyzer: ImageAnalyzer(), modelContainer: Persistence.makeContainer(inMemory: true), actionPerformers: [:])
    RootView(dependencies: dependencies)
        .modelContainer(dependencies.modelContainer)
}
#endif
