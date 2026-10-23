import CoreGraphics
import Foundation

@testable import SlothRoll

/// Ordered record of what the fakes were asked to do, shared across them.
actor ScanEventLog {
    private(set) var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }
}

/// A 1-pixel-high image whose width identifies the fake asset it came from.
func fakeImage(width: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let image = context?.makeImage() else { fatalError("Couldn't draw a test image") }
    return image
}

/// Library of fake assets, newest first. Asset `n` has an image `n` pixels wide.
struct FakeScanLibrary: PhotoLibraryProviding {
    struct Asset {
        let id: String
        let width: Int
        var source: ImageSource = .screenshot
        var isOnDevice = true
    }

    var assets: [Asset]
    var access: PhotoAccess = .full
    /// What `deleteAssets` does: true deletes, false is the user declining, nil throws.
    var deletes: Bool? = true
    var log: ScanEventLog?
    /// Albums and the asset IDs in each, newest first.
    var albumContents: [PhotoAlbum: [String]] = [:]

    func requestAccess() async -> PhotoAccess { access }

    func recentImageIDs(limit: Int) async -> [String] {
        Array(assets.map(\.id).prefix(limit))
    }

    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String] { [] }

    func albums() async -> [PhotoAlbum] {
        albumContents.keys.sorted { $0.title < $1.title }
    }

    func imageIDs(inAlbumID albumID: String, limit: Int) async -> [String] {
        Array((albumContents.first { $0.key.id == albumID }?.value ?? []).prefix(limit))
    }

    func loadImage(assetID: String) async -> LibraryImage? {
        guard let asset = assets.first(where: { $0.id == assetID }), asset.isOnDevice else {
            return nil
        }
        return LibraryImage(
            assetID: asset.id, image: fakeImage(width: asset.width), thumbnail: nil,
            capturedAt: Date(timeIntervalSince1970: Double(1_000_000 - asset.width)),
            source: asset.source)
    }

    func loadPreview(assetID: String, maxPixels: Int) async -> CGImage? {
        assets.first(where: { $0.id == assetID }).map { fakeImage(width: $0.width) }
    }

    func deleteAssets(ids: [String]) async throws(PipelineError) -> Bool {
        await log?.append("delete \(ids.joined(separator: ","))")
        guard let deletes else { throw .deleteFailed }
        return deletes
    }
}

/// Returns the signals set for the image's width; nil (not measurable) for any other width.
struct FakeAnalyzer: ImageAnalyzing {
    var signals: [Int: ImageSignals] = [:]

    func signals(for image: CGImage) async -> ImageSignals? {
        signals[image.width]
    }
}

extension ImageSignals {
    /// Sharp, contrasty image with the given feature print.
    static func sharp(print: [Float]) -> ImageSignals {
        ImageSignals(sharpness: 5_000, contrast: 60, featurePrint: print)
    }

    static let blurry = ImageSignals(sharpness: 1, contrast: 60, featurePrint: [9, 9])
}

/// Candidate when the image width is in `candidateWidths`.
struct FakeTriage: ImageTriaging {
    let candidateWidths: Set<Int>
    let log: ScanEventLog

    func isCandidate(_ image: CGImage) async -> Bool {
        await log.append("triage \(image.width)")
        return candidateWidths.contains(image.width)
    }
}

/// Answers with the JSON for the image's width (or a fixed event), logs every call, can
/// run a hook during the first read, and can fail to load.
actor FakeScanVLM: VLMServing {
    nonisolated let modelID = "fake/scan"
    nonisolated let downloadProgress = AsyncStream<Double> { $0.finish() }
    nonisolated let downloadSizeBytes: Int64 = 0

    func isDownloaded() async -> Bool { true }

    func download(progress: @escaping @Sendable (Double) -> Void) async throws {}

    private let log: ScanEventLog
    private let answers: [Int: String]
    /// Answers to the cleanup "still useful?" question, by image width; "yes" otherwise.
    private let cleanupAnswers: [Int: String]
    private let failsToLoad: Bool
    private var firstReadHook: (@Sendable () async -> Void)?

    init(
        log: ScanEventLog, answers: [Int: String] = [:], cleanupAnswers: [Int: String] = [:],
        failsToLoad: Bool = false
    ) {
        self.log = log
        self.answers = answers
        self.cleanupAnswers = cleanupAnswers
        self.failsToLoad = failsToLoad
    }

    func setFirstReadHook(_ hook: @escaping @Sendable () async -> Void) {
        firstReadHook = hook
    }

    func load() async throws {
        await log.append("load")
        if failsToLoad { throw InferenceError.loadFailed(reason: "test") }
    }

    func describe(image: CGImage, prompt: String) async throws -> String {
        if prompt == UsefulnessQuestion.prompt {
            await log.append("ask \(image.width)")
            return cleanupAnswers[image.width] ?? "Yes."
        }
        await log.append("read \(image.width)")
        if let hook = firstReadHook {
            firstReadHook = nil
            await hook()
        }
        return answers[image.width]
            ?? #"{"type":"event","title":"Cena","date":"2026-10-24","confidence":"high"}"#
    }

    func unload() async {
        await log.append("unload")
    }
}
