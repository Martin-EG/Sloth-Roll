import SwiftUI

/// Settings tab: how many screenshots a scan reads, "Rescan everything", and what model
/// runs on the phone. Debug builds add the eval screen and last scan stats.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    /// Opens the debug eval screen (debug builds only).
    var onOpenEval: (() -> Void)?

    @AppStorage(SettingsKey.scanLimit) private var scanLimit = PipelineConfig.scanLimit
    @State private var isConfirmingRescan = false
    #if DEBUG
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = true
    #endif

    var body: some View {
        Form {
            scanSection
            modelSection
            Section {
                LabeledContent("Version", value: viewModel.appVersion)
            }
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .task { await viewModel.refreshModelStatus() }
    }

    private var scanSection: some View {
        Section {
            Picker("Screenshots per scan", selection: $scanLimit) {
                ForEach(PipelineConfig.scanLimitOptions, id: \.self) { Text("\($0)").tag($0) }
            }
            Button(role: .destructive) {
                isConfirmingRescan = true
            } label: {
                Label("Rescan everything", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.red)
            }
            .disabled(viewModel.isScanning)
            .confirmationDialog(
                "Rescan everything?", isPresented: $isConfirmingRescan, titleVisibility: .visible
            ) {
                Button("Rescan everything", role: .destructive) { viewModel.rescanEverything() }
            } message: {
                Text("Sloth Roll forgets what it read and reads your screenshots again on the next scan. Cards you already did stay done. Expenses are kept.")
            }
        } header: {
            Text("Scan")
        } footer: {
            if viewModel.didResetCache {
                Text("Done. Tap Scan to read your screenshots again.")
            } else {
                Text("More screenshots per scan takes longer.")
            }
        }
    }

    private var modelSection: some View {
        Section {
            LabeledContent("Model") {
                Text(viewModel.modelID)
                    .font(.footnote.monospaced())
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            LabeledContent("Size", value: viewModel.modelSizeText)
            LabeledContent("Status", value: modelStatus)
            Label("Runs on-device. Nothing is uploaded.", systemImage: "lock.iphone")
                .foregroundStyle(.tint)
        } header: {
            Text("Model")
        }
    }

    private var modelStatus: String {
        switch viewModel.isModelDownloaded {
        case .none: "Checking…"
        case .some(true): "On this iPhone"
        case .some(false): "Downloads on next scan"
        }
    }

    #if DEBUG
    @ViewBuilder private var debugSection: some View {
        Section("Debug") {
            if let onOpenEval {
                Button("Eval screen", systemImage: "checklist", action: onOpenEval)
            }
            Button("Show onboarding again", systemImage: "arrow.uturn.backward") {
                hasCompletedOnboarding = false
            }
        }
        if let stats = viewModel.lastStats {
            ScanStatsSection(stats: stats)
        }
    }
    #endif
}
