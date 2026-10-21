import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct ScanViewModelTests {
    private let container = Persistence.makeContainer(inMemory: true)
    private let log = ScanEventLog()

    private func makeViewModel(
        assets: [FakeScanLibrary.Asset], access: PhotoAccess = .full, vlm: FakeScanVLM? = nil
    ) -> ScanViewModel {
        ScanViewModel(
            coordinator: ScanCoordinator(
                vlm: vlm ?? FakeScanVLM(log: log),
                photoLibrary: FakeScanLibrary(assets: assets, access: access),
                triage: FakeTriage(candidateWidths: [1], log: log), analyzer: FakeAnalyzer(),
                modelContext: container.mainContext))
    }

    @Test func emptyLibrarySaysThereIsNothingNew() async {
        let viewModel = makeViewModel(assets: [])

        await viewModel.scan(limit: 25)

        #expect(viewModel.statusMessage?.hasPrefix("No new screenshots") == true)
        #expect(!viewModel.isStatusWarning)
    }

    @Test func finishedScanCountsNewCards() async {
        let viewModel = makeViewModel(assets: [.init(id: "a1", width: 1), .init(id: "a2", width: 2)])

        await viewModel.scan(limit: 25)

        #expect(viewModel.statusMessage == "Found 1 new card.")
    }

    @Test func deniedAccessShowsThePermissionScreen() async {
        let viewModel = makeViewModel(assets: [.init(id: "a1", width: 1)], access: .denied)

        await viewModel.scan(limit: 25)

        #expect(viewModel.hasNoPhotoAccess)
        #expect(viewModel.statusMessage == nil)
    }

    @Test func modelFailureShowsAnErrorAndOffersRetry() async {
        let viewModel = makeViewModel(
            assets: [.init(id: "a1", width: 1)], vlm: FakeScanVLM(log: log, failsToLoad: true))

        await viewModel.scan(limit: 25)

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.scanButtonTitle == "Try again")
    }
}
