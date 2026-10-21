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

    func requestAccess() async -> PhotoAccess { access }

    func recentImageIDs(limit: Int) async -> [String] {
        Array(assets.map(\.id).prefix(limit))
    }

    func assetIDs(inAlbum title: String) async throws(PipelineError) -> [String] { [] }

    func loadImage(assetID: String) async -> LibraryImage? {
        guard let asset = assets.first(where: { $0.id == assetID }), asset.isOnDevice else {
            return nil
        }
        return LibraryImage(
            assetID: asset.id, image: fakeImage(width: asset.width), thumbnail: nil,
            capturedAt: Date(timeIntervalSince1970: Double(1_000_000 - asset.width)),
            source: asset.source)
    }
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

/// Answers with the JSON for the image's width (or a fixed event), logs every call, and can
/// run a hook during the first read.
actor FakeScanVLM: VLMServing {
    nonisolated let modelID = "fake/scan"
    nonisolated let downloadProgress = AsyncStream<Double> { $0.finish() }

    private let log: ScanEventLog
    private let answers: [Int: String]
    private var firstReadHook: (@Sendable () async -> Void)?

    init(log: ScanEventLog, answers: [Int: String] = [:]) {
        self.log = log
        self.answers = answers
    }

    func setFirstReadHook(_ hook: @escaping @Sendable () async -> Void) {
        firstReadHook = hook
    }

    func load() async throws {
        await log.append("load")
    }

    func describe(image: CGImage, prompt: String) async throws -> String {
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
