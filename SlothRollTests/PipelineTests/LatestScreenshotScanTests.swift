import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct LatestScreenshotScanTests {
    private let container = Persistence.makeContainer(inMemory: true)
    private let log = ScanEventLog()

    private func makeCoordinator(
        assets: [FakeScanLibrary.Asset], candidates: Set<Int>, vlm: FakeScanVLM? = nil,
        access: PhotoAccess = .full
    ) -> ScanCoordinator {
        ScanCoordinator(
            vlm: vlm ?? FakeScanVLM(log: log),
            photoLibrary: FakeScanLibrary(assets: assets, access: access),
            triage: FakeTriage(candidateWidths: candidates, log: log), analyzer: FakeAnalyzer(),
            modelContext: container.mainContext)
    }

    private func items() throws -> [String: ScreenshotItem] {
        let all = try container.mainContext.fetch(FetchDescriptor<ScreenshotItem>())
        return Dictionary(uniqueKeysWithValues: all.map { ($0.assetID, $0) })
    }

    private func assets(_ widths: ClosedRange<Int>) -> [FakeScanLibrary.Asset] {
        widths.map { .init(id: "a\($0)", width: $0) }
    }

    @Test func readsOnlyTheNewestImageAndUnloads() async throws {
        let coordinator = makeCoordinator(assets: assets(1...3), candidates: [1, 2, 3])

        let outcome = await coordinator.scanLatestScreenshot()

        #expect(outcome == .card(.event))
        #expect(coordinator.phase == .finished)
        #expect(await log.events == ["triage 1", "load", "read 1", "unload"])
        let saved = try items()
        #expect(saved["a1"]?.status == .extracted)
        #expect(saved["a2"] == nil)
    }

    @Test func stepsOverCameraPhotosTakenAfterTheScreenshot() async throws {
        var library = assets(1...2)
        library[0].source = .camera
        let coordinator = makeCoordinator(assets: library, candidates: [1, 2])

        let outcome = await coordinator.scanLatestScreenshot()

        #expect(outcome == .card(.event))
        #expect(await log.events == ["triage 2", "load", "read 2", "unload"])
        #expect(try items()["a1"]?.skipReason == .camera)
    }

    @Test func littleTextFindsNothingWithoutLoadingTheModel() async throws {
        let coordinator = makeCoordinator(assets: assets(1...2), candidates: [])

        let outcome = await coordinator.scanLatestScreenshot()

        #expect(outcome == .nothingFound)
        #expect(await log.events == ["triage 1"])
        #expect(try items()["a1"]?.skipReason == .littleText)
    }

    @Test func noneAnswerFindsNothing() async throws {
        let vlm = FakeScanVLM(log: log, answers: [1: #"{"type":"none","title":"","confidence":"high"}"#])
        let coordinator = makeCoordinator(assets: assets(1...1), candidates: [1], vlm: vlm)

        #expect(await coordinator.scanLatestScreenshot() == .nothingFound)
    }

    @Test func alreadyReadScreenshotIsNotReadAgain() async throws {
        let coordinator = makeCoordinator(assets: assets(1...1), candidates: [1])
        _ = await coordinator.scanLatestScreenshot()

        #expect(await coordinator.scanLatestScreenshot() == .card(.event))
        #expect(await log.events.count(where: { $0 == "read 1" }) == 1)

        let item = try #require(try items()["a1"])
        item.status = .done
        #expect(await coordinator.scanLatestScreenshot() == .alreadyDone)
    }

    @Test func emptyLibraryHasNoScreenshot() async {
        let coordinator = makeCoordinator(assets: [], candidates: [])

        #expect(await coordinator.scanLatestScreenshot() == .noScreenshot)
        #expect(coordinator.phase == .finished)
    }

    @Test func deniedAccessSetsTheAccessPhase() async {
        let coordinator = makeCoordinator(assets: assets(1...1), candidates: [1], access: .denied)

        #expect(await coordinator.scanLatestScreenshot() == .noPhotoAccess)
        #expect(coordinator.phase == .noPhotoAccess)
        #expect(await log.events.isEmpty)
    }

    @Test func modelLoadFailureKeepsTheTriagedItemForRetry() async throws {
        let vlm = FakeScanVLM(log: log, failsToLoad: true)
        let coordinator = makeCoordinator(assets: assets(1...1), candidates: [1], vlm: vlm)

        let outcome = await coordinator.scanLatestScreenshot()

        guard case .modelLoadFailed = outcome else {
            Issue.record("Expected a model load failure, got \(outcome)")
            return
        }
        #expect(coordinator.phase.isModelLoadFailure)
        #expect(try items()["a1"]?.status == .triaged)
    }
}
