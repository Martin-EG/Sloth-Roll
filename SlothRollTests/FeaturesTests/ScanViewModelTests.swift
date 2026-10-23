import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct ScanViewModelTests {
    private let container = Persistence.makeContainer(inMemory: true)
    private let log = ScanEventLog()

    private func makeViewModel(
        assets: [FakeScanLibrary.Asset], access: PhotoAccess = .full, vlm: FakeScanVLM? = nil,
        albums: [PhotoAlbum: [String]] = [:]
    ) -> ScanViewModel {
        let library = FakeScanLibrary(assets: assets, access: access, albumContents: albums)
        return ScanViewModel(
            coordinator: ScanCoordinator(
                vlm: vlm ?? FakeScanVLM(log: log),
                photoLibrary: library,
                triage: FakeTriage(candidateWidths: [1], log: log), analyzer: FakeAnalyzer(),
                modelContext: container.mainContext),
            photoLibrary: library)
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

    @Test func albumsLoadAndADeletedAlbumFallsBackToAllPhotos() async {
        let screenshots = PhotoAlbum(id: "s", title: "Screenshots", imageCount: 2)
        let viewModel = makeViewModel(assets: [], albums: [screenshots: ["a1", "a2"]])

        await viewModel.loadAlbums()

        #expect(viewModel.albums == [screenshots])
        #expect(viewModel.validAlbumID("s") == "s")
        #expect(viewModel.validAlbumID("gone") == nil)
        #expect(viewModel.validAlbumID("") == nil)
    }

    @Test func albumsNeedPhotosAccess() async {
        let viewModel = makeViewModel(
            assets: [], access: .denied,
            albums: [PhotoAlbum(id: "s", title: "Screenshots", imageCount: 1): ["a1"]])

        await viewModel.loadAlbums()

        #expect(viewModel.albumsNeedAccess)
        #expect(viewModel.albums.isEmpty)
    }

    @Test func sourceLabelNamesTheAlbum() {
        #expect(ScanViewModel.sourceLabel(albumTitle: "") == "All recent photos")
        #expect(ScanViewModel.sourceLabel(albumTitle: "To sort") == "Album: To sort")
    }
}
