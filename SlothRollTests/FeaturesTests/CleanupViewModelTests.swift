import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct CleanupViewModelTests {
    private let container = Persistence.makeContainer(inMemory: true)
    private let log = ScanEventLog()

    private func makeCandidates() -> [ScreenshotItem] {
        ["a1", "a2", "a3"].map { id in
            let item = ScreenshotItem(
                assetID: id, status: .skipped, skipReason: .littleText, capturedAt: nil)
            item.cleanupReason = .notUseful
            container.mainContext.insert(item)
            return item
        }
    }

    private func makeViewModel(deletes: Bool? = true) -> CleanupViewModel {
        CleanupViewModel(
            photoLibrary: FakeScanLibrary(assets: [], deletes: deletes, log: log),
            context: container.mainContext)
    }

    private func remainingIDs() throws -> Set<String> {
        Set(try container.mainContext.fetch(FetchDescriptor<ScreenshotItem>()).map(\.assetID))
    }

    @Test func everythingStartsSelected() {
        let items = makeCandidates()
        let viewModel = makeViewModel()

        #expect(viewModel.selectedCount(in: items) == 3)
        #expect(viewModel.deleteButtonTitle(count: 3) == "Delete 3 screenshots")
        #expect(viewModel.deleteButtonTitle(count: 1) == "Delete 1 screenshot")
    }

    @Test func deletesTheSelectionAndKeepsTheRestForGood() async throws {
        let items = makeCandidates()
        let viewModel = makeViewModel()
        viewModel.toggle(items[1])

        await viewModel.deleteSelected(from: items)

        #expect(await log.events == ["delete a1,a3"])
        #expect(try remainingIDs() == ["a2"])
        #expect(items[1].cleanupReason == nil)
        #expect(items[1].cleanupKeptAt != nil)
        #expect(viewModel.toast?.message == "Moved 2 screenshots to Recently Deleted.")
    }

    @Test func decliningInPhotosChangesNothing() async throws {
        let items = makeCandidates()
        let viewModel = makeViewModel(deletes: false)

        await viewModel.deleteSelected(from: items)

        #expect(try remainingIDs() == ["a1", "a2", "a3"])
        #expect(items.allSatisfy { $0.cleanupReason == .notUseful })
        #expect(viewModel.toast == nil)
    }

    @Test func failureShowsAPlainMessage() async throws {
        let items = makeCandidates()
        let viewModel = makeViewModel(deletes: nil)

        await viewModel.deleteSelected(from: items)

        #expect(try remainingIDs().count == 3)
        #expect(viewModel.toast?.message == PipelineError.deleteFailed.errorDescription)
        #expect(viewModel.toast?.isError == true)
    }

    @Test func toggleAllFlipsBetweenAllAndNone() {
        let items = makeCandidates()
        let viewModel = makeViewModel()

        viewModel.toggleAll(in: items)
        #expect(viewModel.selectedCount(in: items) == 0)
        viewModel.toggleAll(in: items)
        #expect(viewModel.allSelected(in: items))
    }
}
