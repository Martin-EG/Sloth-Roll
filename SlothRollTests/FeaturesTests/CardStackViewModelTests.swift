import Foundation
import SwiftData
import Testing

@testable import SlothRoll

/// Succeeds with a fixed message, or throws the given error.
private struct FakePerformer: ActionPerformer {
    var error: ActionError?

    func perform(_ result: ActionResult, assetID: String) async throws -> ActionOutcome {
        if let error { throw error }
        return ActionOutcome(message: "Did \(result.title)")
    }
}

@MainActor
struct CardStackViewModelTests {
    private let container = Persistence.makeContainer(inMemory: true)

    private func makeItem(_ type: ActionType = .event) -> ScreenshotItem {
        let item = ScreenshotItem(assetID: "a1", status: .extracted, capturedAt: nil)
        item.result = ActionResult(type: type, title: "Cena", date: "2026-10-24", confidence: .high)
        container.mainContext.insert(item)
        return item
    }

    private func makeViewModel(error: ActionError? = nil) -> CardStackViewModel {
        CardStackViewModel(
            performers: [.event: FakePerformer(error: error)],
            photoLibrary: FakeScanLibrary(assets: []), context: container.mainContext)
    }

    @Test func successMarksDoneAndToastsTheOutcome() async {
        let item = makeItem()
        let viewModel = makeViewModel()

        let left = await viewModel.perform(item)

        #expect(left)
        #expect(item.status == .done)
        #expect(viewModel.toast?.message == "Did Cena")
        #expect(viewModel.toast?.isError == false)
    }

    @Test func failureKeepsTheCardAndShowsTheMessage() async {
        let item = makeItem()
        let viewModel = makeViewModel(error: .calendarAccessDenied)

        let left = await viewModel.perform(item)

        #expect(!left)
        #expect(item.status == .extracted)
        #expect(viewModel.toast?.message == ActionError.calendarAccessDenied.errorDescription)
        #expect(viewModel.toast?.isError == true)
        #expect(!viewModel.isPerforming)
    }

    @Test func typeWithoutPerformerKeepsTheCard() async {
        let item = makeItem(.place)
        let viewModel = makeViewModel()

        #expect(await viewModel.perform(item) == false)
        #expect(item.status == .extracted)
    }

    @Test func skipMarksSkipped() {
        let item = makeItem()

        #expect(makeViewModel().skip(item))
        #expect(item.status == .skipped)
    }

    @Test func editReplacesTheResult() throws {
        let item = makeItem()
        var edited = try #require(item.result)
        edited.time = "21:30"

        makeViewModel().save(edited, for: item)

        #expect(item.result?.time == "21:30")
    }
}
