import CoreGraphics
import Testing

@testable import SlothRoll

/// Scripted model: returns (or throws) the queued answers in order and records prompts.
private actor ScriptedVLM: VLMServing {
    enum Answer {
        case text(String)
        case failure
    }

    nonisolated let modelID = "fake/scripted"
    nonisolated let downloadProgress = AsyncStream<Double> { $0.finish() }

    private var answers: [Answer]
    private(set) var prompts: [String] = []

    init(_ answers: [Answer]) {
        self.answers = answers
    }

    func load() async throws {}

    func describe(image: CGImage, prompt: String) async throws -> String {
        prompts.append(prompt)
        guard !answers.isEmpty else { throw InferenceError.emptyOutput }
        switch answers.removeFirst() {
        case .text(let text): return text
        case .failure: throw InferenceError.generationFailed(reason: "test")
        }
    }

    func unload() async {}
}

struct ExtractorTests {
    private static let good = #"{"type":"place","title":"Contramar","location":"Roma Norte","confidence":"high"}"#

    private static func image() throws -> CGImage {
        let context = try #require(
            CGContext(
                data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try #require(context.makeImage())
    }

    @Test func firstGoodAnswerIsUsed() async throws {
        let vlm = ScriptedVLM([.text(Self.good)])
        let report = await Extractor(vlm: vlm).extractWithReport(image: try Self.image())

        #expect(report.result.title == "Contramar")
        #expect(report.attempts == 1)
        #expect(!report.usedFallback)
    }

    @Test func badAnswerIsRetriedOnceWithStricterPrompt() async throws {
        let vlm = ScriptedVLM([.text("I see a restaurant."), .text(Self.good)])
        let report = await Extractor(vlm: vlm).extractWithReport(image: try Self.image())

        #expect(report.result.type == .place)
        #expect(report.attempts == 2)
        let prompts = await vlm.prompts
        #expect(prompts.count == 2)
        #expect(prompts[1].contains("could not be used (no JSON object found)"))
    }

    @Test func twoBadAnswersReturnFallback() async throws {
        let vlm = ScriptedVLM([.text("nope"), .text(#"{"type":"event","title":"X","date":"2026-13-01"}"#)])
        let result = await Extractor(vlm: vlm).extract(image: try Self.image())

        #expect(result == ActionResult(type: .none, title: "Couldn't read this one", confidence: .low))
        #expect(await vlm.prompts.count == 2)
    }

    @Test func modelErrorsNeverThrow() async throws {
        let vlm = ScriptedVLM([.failure, .failure])
        let report = await Extractor(vlm: vlm).extractWithReport(image: try Self.image())

        #expect(report.usedFallback)
        #expect(report.attempts == 2)
        #expect(report.rawOutputs.isEmpty)
    }

    @Test func generationErrorThenGoodAnswerSucceeds() async throws {
        let vlm = ScriptedVLM([.failure, .text(Self.good)])
        let report = await Extractor(vlm: vlm).extractWithReport(image: try Self.image())

        #expect(!report.usedFallback)
        // A model crash isn't a format problem, so the retry uses the normal prompt.
        let prompts = await vlm.prompts
        #expect(prompts[0] == prompts[1])
    }
}
