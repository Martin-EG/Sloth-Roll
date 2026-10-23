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
        access: PhotoAccess = .full, limit: Int = PipelineConfig.scanLimit,
        analyzer: FakeAnalyzer = FakeAnalyzer()
    ) -> ScanCoordinator {
        ScanCoordinator(
            vlm: vlm ?? FakeScanVLM(log: log),
            photoLibrary: FakeScanLibrary(assets: assets, access: access),
            triage: FakeTriage(candidateWidths: candidates, log: log), analyzer: analyzer,
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

    @Test func albumScanTriagesOnlyThatAlbum() async throws {
        let album = PhotoAlbum(id: "album", title: "To sort", imageCount: 2)
        let coordinator = ScanCoordinator(
            vlm: FakeScanVLM(log: log),
            photoLibrary: FakeScanLibrary(assets: assets(1...4), albumContents: [album: ["a2", "a4"]]),
            triage: FakeTriage(candidateWidths: [], log: log), analyzer: FakeAnalyzer(),
            modelContext: container.mainContext)

        await coordinator.scan(albumID: "album")

        #expect(Set(try items().keys) == ["a2", "a4"])
        #expect(await log.events == ["triage 2", "triage 4"])

        // A missing album scans nothing instead of falling back to the whole library.
        await coordinator.scan(albumID: "gone")
        #expect(coordinator.lastStats?.newImages == 0)
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

@MainActor
struct ScanCoordinatorCleanupTests {
    private let container = Persistence.makeContainer(inMemory: true)
    private let log = ScanEventLog()

    private func makeCoordinator(
        widths: ClosedRange<Int>, candidates: Set<Int> = [], analyzer: FakeAnalyzer,
        cleanupAnswers: [Int: String] = [:]
    ) -> ScanCoordinator {
        ScanCoordinator(
            vlm: FakeScanVLM(log: log, cleanupAnswers: cleanupAnswers),
            photoLibrary: FakeScanLibrary(assets: widths.map { .init(id: "a\($0)", width: $0) }),
            triage: FakeTriage(candidateWidths: candidates, log: log), analyzer: analyzer,
            modelContext: container.mainContext)
    }

    private func items() throws -> [String: ScreenshotItem] {
        let all = try container.mainContext.fetch(FetchDescriptor<ScreenshotItem>())
        return Dictionary(uniqueKeysWithValues: all.map { ($0.assetID, $0) })
    }

    @Test func blurryByRuleDuplicatesKeepNewestAndModelJudgesTheRest() async throws {
        // a1 is newest (FakeScanLibrary dates go down as width goes up); a1 and a2 look alike.
        let analyzer = FakeAnalyzer(signals: [
            1: .sharp(print: [0, 0]), 2: .sharp(print: [0, 0.1]), 3: .blurry,
            4: .sharp(print: [5, 5]), 5: .sharp(print: [-5, 5]),
        ])
        let coordinator = makeCoordinator(
            widths: 1...5, analyzer: analyzer, cleanupAnswers: [4: "No."])

        await coordinator.scan()

        let saved = try items()
        #expect(saved["a1"]?.cleanupReason == nil)
        #expect(saved["a2"]?.cleanupReason == .duplicate)
        #expect(saved["a3"]?.cleanupReason == .blurry)
        #expect(saved["a4"]?.cleanupReason == .notUseful)
        #expect(saved["a5"]?.cleanupReason == nil)
        #expect(saved["a5"]?.cleanupCheckedAt != nil)
        // Only the leftovers are asked, with one model load for the whole scan.
        let events = await log.events
        #expect(events.filter { $0.hasPrefix("ask") } == ["ask 1", "ask 4", "ask 5"])
        #expect(events.count(where: { $0 == "load" }) == 1)
        #expect(events.last == "unload")
        #expect(coordinator.lastStats?.cleanupCandidates == 3)
    }

    @Test func extractionAndCleanupShareOneModelLoad() async throws {
        let analyzer = FakeAnalyzer(signals: [1: .sharp(print: [0, 0]), 2: .sharp(print: [5, 5])])
        let coordinator = makeCoordinator(widths: 1...2, candidates: [1], analyzer: analyzer)

        await coordinator.scan()

        #expect(await log.events.suffix(4) == ["load", "read 1", "ask 2", "unload"])
        // The extracted card isn't a cleanup candidate.
        #expect(try items()["a1"]?.cleanupCheckedAt == nil)
    }

    @Test func swipedLeftItemsAreJudgedNextScanAndJudgedItemsArentAskedTwice() async throws {
        let analyzer = FakeAnalyzer(signals: [1: .sharp(print: [0, 0])])
        let coordinator = makeCoordinator(
            widths: 1...1, candidates: [1], analyzer: analyzer, cleanupAnswers: [1: "no"])
        await coordinator.scan()
        let card = try #require(items()["a1"])
        card.status = .skipped
        card.skipReason = .swipedLeft

        await coordinator.scan()
        await coordinator.scan()

        #expect(card.cleanupReason == .notUseful)
        #expect(await log.events.count(where: { $0 == "ask 1" }) == 1)
    }

    @Test func olderSkippedItemsWithoutSignalsAreMeasuredBeforeTheModelLoads() async throws {
        let item = ScreenshotItem(
            assetID: "a1", status: .skipped, skipReason: .littleText, capturedAt: nil)
        container.mainContext.insert(item)
        let analyzer = FakeAnalyzer(signals: [1: .blurry])
        let coordinator = makeCoordinator(widths: 1...1, analyzer: analyzer)

        await coordinator.scan()

        #expect(item.sharpness != nil)
        #expect(item.cleanupReason == .blurry)
        #expect(await !log.events.contains("load"))
    }

    @Test func keptItemsAndCameraPhotosAreNeverOffered() async throws {
        let kept = ScreenshotItem(
            assetID: "a1", status: .skipped, skipReason: .littleText, capturedAt: nil)
        kept.cleanupKeptAt = .now
        let camera = ScreenshotItem(
            assetID: "a2", status: .skipped, skipReason: .camera, capturedAt: nil)
        container.mainContext.insert(kept)
        container.mainContext.insert(camera)
        let coordinator = makeCoordinator(
            widths: 1...2, analyzer: FakeAnalyzer(signals: [1: .blurry, 2: .blurry]))

        await coordinator.scan()

        #expect(kept.cleanupReason == nil && kept.sharpness == nil)
        #expect(camera.cleanupReason == nil && camera.sharpness == nil)
    }
}
