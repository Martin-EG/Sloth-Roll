import SwiftUI

/// Top-level tabs: Scan (scan button + review cards) and Expenses, with a debug menu (eval
/// screen, last scan stats, cache reset) on the Scan tab in debug builds.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var scanViewModel: ScanViewModel
    @State private var cardStackViewModel: CardStackViewModel
    @State private var expensesViewModel: ExpensesViewModel
    #if DEBUG
    @State private var evalViewModel: EvalViewModel
    @State private var isShowingEval = false
    @State private var isShowingStats = false
    #endif

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let context = dependencies.modelContainer.mainContext
        _scanViewModel = State(initialValue: ScanViewModel(coordinator: dependencies.scanCoordinator))
        _cardStackViewModel = State(
            initialValue: CardStackViewModel(
                performers: dependencies.actionPerformers,
                photoLibrary: dependencies.photoLibrary, context: context))
        _expensesViewModel = State(initialValue: ExpensesViewModel(context: context))
        #if DEBUG
        _evalViewModel = State(
            initialValue: EvalViewModel(
                vlm: dependencies.vlm, photoLibrary: dependencies.photoLibrary))
        #endif
    }

    var body: some View {
        TabView {
            Tab("Scan", systemImage: "rectangle.stack") {
                NavigationStack {
                    ScanView(viewModel: scanViewModel, cardStackViewModel: cardStackViewModel)
                        #if DEBUG
                        .toolbar { debugMenu }
                        #endif
                }
            }
            Tab("Expenses", systemImage: "creditcard") {
                NavigationStack {
                    ExpenseListView(viewModel: expensesViewModel)
                }
            }
        }
        #if DEBUG
        .sheet(isPresented: $isShowingEval) {
            EvalView(viewModel: evalViewModel)
        }
        .sheet(isPresented: $isShowingStats) {
            NavigationStack {
                List {
                    if let stats = scanViewModel.stats {
                        ScanStatsSection(stats: stats)
                    } else {
                        Text("No scan yet.")
                    }
                }
                .navigationTitle("Last scan")
            }
            .presentationDetents([.medium, .large])
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
            Button("Last scan stats", systemImage: "chart.bar") { isShowingStats = true }
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
        modelContainer: Persistence.makeContainer(inMemory: true), actionPerformers: [:])
    RootView(dependencies: dependencies)
        .modelContainer(dependencies.modelContainer)
}
#endif
