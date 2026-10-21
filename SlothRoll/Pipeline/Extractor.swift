import CoreGraphics
import Foundation

/// Reads one screenshot with the VLM and returns a validated `ActionResult`. Never throws:
/// unusable answers get one stricter retry, then a safe "couldn't read" result.
struct Extractor: Sendable {
    static let fallbackResult = ActionResult(
        type: .none, title: PipelineConfig.fallbackTitle, confidence: .low)

    private let vlm: any VLMServing
    private let parser: ResultParser
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    init(
        vlm: any VLMServing, parser: ResultParser = ResultParser(),
        calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.vlm = vlm
        self.parser = parser
        self.calendar = calendar
        self.now = now
    }

    /// `capturedAt` is when the screenshot was taken; relative dates resolve against it.
    /// Without it they resolve against today.
    func extract(image: CGImage, capturedAt: Date? = nil) async -> ActionResult {
        await extractWithReport(image: image, capturedAt: capturedAt).result
    }

    func extractWithReport(image: CGImage, capturedAt: Date? = nil) async -> ExtractionReport {
        let clock = ContinuousClock()
        let start = clock.now
        let prompt = ExtractionPrompt(capturedAt: capturedAt, today: now(), calendar: calendar)
        var rawOutputs: [String] = []
        var problems: [String] = []
        var attemptsMade = 0
        // Set only when the model answered but the answer was unusable; drives the retry wording.
        var parseProblem: String?

        for attempt in 1...PipelineConfig.maxExtractionAttempts {
            if Task.isCancelled { break }
            attemptsMade = attempt
            let text = parseProblem.map { prompt.retryText(previousProblem: $0) } ?? prompt.text

            let raw: String
            do {
                raw = try await vlm.describe(image: image, prompt: text)
            } catch {
                problems.append("generation: \(error.localizedDescription)")
                Log.pipeline.error(
                    "extract attempt=\(attempt) generation_failed error=\(String(describing: error), privacy: .public)"
                )
                continue
            }
            rawOutputs.append(raw)

            do {
                let result = try parser.parse(raw)
                Log.pipeline.info(
                    "extract attempt=\(attempt) ok type=\(result.type.rawValue, privacy: .public)")
                return ExtractionReport(
                    result: result, attempts: attempt, rawOutputs: rawOutputs,
                    problems: problems, usedFallback: false,
                    duration: start.duration(to: clock.now))
            } catch {
                parseProblem = Self.describe(error)
                problems.append(Self.describe(error))
                Log.pipeline.error(
                    "extract attempt=\(attempt) parse_failed error=\(String(describing: error), privacy: .public) raw=\(raw)"
                )
            }
        }

        return ExtractionReport(
            result: Self.fallbackResult, attempts: attemptsMade,
            rawOutputs: rawOutputs, problems: problems, usedFallback: true,
            duration: start.duration(to: clock.now))
    }

    /// Short reason fed back to the model on retry.
    private static func describe(_ error: PipelineError) -> String {
        switch error {
        case .noJSONObject: "no JSON object found"
        case .malformedJSON: "the JSON was malformed"
        case .missingType: "the \"type\" key was missing; it must be event, place, receipt, or none"
        case .invalidDate(let date): "\"\(date)\" is not a real YYYY-MM-DD date"
        case .invalidTime(let time): "\"\(time)\" is not a 24-hour HH:mm time"
        case .negativeAmount: "amount must not be negative"
        case .missingTitle: "title was empty"
        case .photoAccessDenied, .albumNotFound, .deleteFailed: "unexpected error"
        }
    }
}
