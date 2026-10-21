#if DEBUG
import CoreGraphics

/// Canned stand-in for the VLM so SwiftUI previews render without MLX or a download.
actor PreviewVLM: VLMServing {
    nonisolated let modelID = "preview/fake-vlm"
    nonisolated let downloadProgress: AsyncStream<Double>
    private let continuation: AsyncStream<Double>.Continuation

    private let delay: Duration
    private let failLoad: Bool

    init(delay: Duration = .milliseconds(300), failLoad: Bool = false) {
        self.delay = delay
        self.failLoad = failLoad
        (downloadProgress, continuation) = AsyncStream.makeStream(of: Double.self)
    }

    func load() async throws {
        for step in 1...4 {
            try await Task.sleep(for: delay / 4)
            continuation.yield(Double(step) / 4)
        }
        if failLoad { throw CancellationError() }
    }

    func describe(image: CGImage, prompt: String) async throws -> String {
        try await Task.sleep(for: delay)
        return """
            {"type":"event","title":"Noche de jazz","date":"2026-10-24","time":"21:00",\
            "location":"Blue Room","amount":null,"currency":null,"confidence":"high"}
            """
    }

    func unload() async {}

    /// Solid-color placeholder sized like an iPhone screenshot.
    nonisolated static func sampleImage() -> CGImage? {
        let width = 1179, height = 2556
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        context.fill(CGRect(x: 120, y: 900, width: width - 240, height: 700))
        return context.makeImage()
    }
}
#endif
