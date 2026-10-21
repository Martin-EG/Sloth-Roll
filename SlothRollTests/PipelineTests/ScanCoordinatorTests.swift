import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct ScanCoordinatorTests {
    private let container = Persistence.makeContainer(inMemory: true)
    private let log = ScanEventLog()

    private func makeCoordinator(
        assets: [FakeScanLibrary.Asset], candidates: Set<Int>, vlm: FakeScanVLM? = nil,
        access: PhotoAccess = .full, limit: Int = PipelineConfig.scanLimit
    ) -> ScanCoordinator {
        ScanCoordinator(
            vlm: vlm ?? FakeScanVLM(log: log),
            photoLibrary: FakeScanLibrary(assets: assets, access: access),
            triage: FakeTriage(candidateWidths: candidates, log: log),
            modelContext: container.mainContext, limit: limit)
    }

    private func items() throws -> [String: ScreenshotItem] {
        let all = try container.mainContext.fetch(FetchDescriptor<ScreenshotItem>())
        return Dictionary(uniqueKeysWithValues: all.map { ($0.assetID, $0) })
    }

    private func assets(_ widths: ClosedRange<Int>) -> [FakeScanLibrary.Asset] {
        widths.map { .init(id: "a\($0)", width: $0) }
    }

    @Test func triagesEverythingBeforeLoadingAndReadsOnlyCandidates() async throws {
        let coordinator = makeCoordinator(assets: assets(1...4), candidates: [1, 3])

        await coordinator.scan()

        #expect(coordinator.phase == .finished)
        #expect(
            await log.events == [
                "triage 1", "triage 2", "triage 3", "triage 4", "load", "read 1", "read 3",
                "unload",
            ])
        let saved = try items()
        #expect(saved["a1"]?.status == .extracted)
        #expect(saved["a1"]?.result?.title == "Cena")
        #expect(saved["a2"]?.status == .skipped)
        #expect(saved["a2"]?.skipReason == .littleText)
        #expect(coordinator.lastStats?.candidates == 2)
        #expect(coordinator.lastStats?.modelReads == 2)
    }

    @Test func rescanSkipsCachedAssetsAndDoesNotLoadModelWithNothingToRead() async throws {
        let coordinator = makeCoordinator(assets: assets(1...2), candidates: [1])
        await coordinator.scan()
        await coordinator.scan()

        let events = await log.events
        #expect(events.count(where: { $0 == "triage 1" }) == 1)
        #expect(events.count(where: { $0 == "load" }) == 1)
        #expect(coordinator.lastStats?.newImages == 0)
    }

    @Test func noneAndFallbackAnswersGetTheirOwnStatus() async throws {
        let vlm = FakeScanVLM(
            log: log,
            answers: [1: #"{"type":"none","title":"","confidence":"high"}"#, 2: "not json"])
        let coordinator = makeCoordinator(assets: assets(1...2), candidates: [1, 2], vlm: vlm)

        await coordinator.scan()

        let saved = try items()
        #expect(saved["a1"]?.status == .skipped)
        #expect(saved["a1"]?.skipReason == SkipReason.noAction)
        #expect(saved["a2"]?.status == .failed)
        #expect(saved["a2"]?.result?.title == PipelineConfig.fallbackTitle)
    }

    @Test func cameraPhotosAreSkippedWithoutCountingTowardTheLimit() async throws {
        var library = assets(1...3)
        library[0].source = .camera
        let coordinator = makeCoordinator(assets: library, candidates: [], limit: 2)

        await coordinator.scan()

        let saved = try items()
        #expect(saved["a1"]?.skipReason == .camera)
        #expect(saved["a2"] != nil && saved["a3"] != nil)
        #expect(await !log.events.contains("triage 1"))
    }

    @Test func limitCapsTriageAndICloudOnlyImagesStayUncached() async throws {
        var library = assets(1...5)
        library[1].isOnDevice = false
        let coordinator = makeCoordinator(assets: library, candidates: [], limit: 2)

        await coordinator.scan()

        let saved = try items()
        #expect(Set(saved.keys) == ["a1", "a3"])
        #expect(coordinator.lastStats?.unavailable == 1)
    }

    @Test func memoryWarningFinishesCurrentItemUnloadsAndPauses() async throws {
        let vlm = FakeScanVLM(log: log)
        let coordinator = makeCoordinator(assets: assets(1...3), candidates: [1, 2, 3], vlm: vlm)
        await vlm.setFirstReadHook { await coordinator.handleMemoryWarning() }

        await coordinator.scan()

        #expect(coordinator.phase == .pausedForMemory)
        #expect(await log.events.suffix(2) == ["read 1", "unload"])
        let saved = try items()
        #expect(saved["a1"]?.status == .extracted)
        #expect(saved["a2"]?.status == .triaged)

        // Resuming reads what was left, newest first, without triaging again.
        await coordinator.scan()
        #expect(coordinator.phase == .finished)
        #expect(try items().values.allSatisfy { $0.status == .extracted })
        #expect(await log.events.suffix(4) == ["load", "read 2", "read 3", "unload"])
    }

    @Test func deniedAccessStopsBeforeAnyWork() async {
        let coordinator = makeCoordinator(assets: assets(1...1), candidates: [], access: .denied)

        await coordinator.scan()

        #expect(coordinator.phase == .noPhotoAccess)
        #expect(await log.events.isEmpty)
    }

    @Test func scanLimitArgumentOverridesTheDefault() async throws {
        let coordinator = makeCoordinator(assets: assets(1...5), candidates: [], limit: 4)

        await coordinator.scan(limit: 2)

        #expect(try items().count == 2)
    }

    @Test func modelLoadFailureKeepsTriageAndRetriesStraightToTheModel() async throws {
        let failing = FakeScanVLM(log: log, failsToLoad: true)
        let coordinator = makeCoordinator(assets: assets(1...2), candidates: [1], vlm: failing)

        await coordinator.scan()

        #expect(
            coordinator.phase
                == .modelLoadFailed(message: InferenceError.loadFailed(reason: "").localizedDescription))
        #expect(try items()["a1"]?.status == .triaged)
        #expect(!coordinator.isRunning)
    }

    @Test func resetCacheForgetsEverythingButDoneItems() async throws {
        let coordinator = makeCoordinator(assets: assets(1...3), candidates: [1, 2])
        await coordinator.scan()
        let handled = try #require(items()["a1"])
        handled.status = .done
        try container.mainContext.save()

        coordinator.resetCache()

        #expect(Set(try items().keys) == ["a1"])
        #expect(coordinator.phase == .idle)
        await coordinator.scan()
        #expect(await log.events.count(where: { $0 == "triage 2" }) == 2)
        #expect(await log.events.count(where: { $0 == "triage 1" }) == 1)
    }
}
