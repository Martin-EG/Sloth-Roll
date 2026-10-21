import Foundation

/// Turns raw model text into a validated `ActionResult`, or a `PipelineError` saying why not.
struct ResultParser: Sendable {
    private static let posix = Locale(identifier: "en_US_POSIX")

    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        self.calendar = calendar
    }

    func parse(_ output: String) throws(PipelineError) -> ActionResult {
        let decoded = try decode(output)
        return try validate(decoded)
    }

    // MARK: - Decoding

    /// Keeps the text from the first "{" to the last "}". If that span isn't valid JSON
    /// (for example stray braces after the object), falls back to the first balanced object.
    private func decode(_ output: String) throws(PipelineError) -> ActionResult {
        guard let start = output.firstIndex(of: "{"),
            let end = output.lastIndex(of: "}"), start < end
        else { throw .noJSONObject }

        let widest = output[start...end]
        let firstError: any Error
        do {
            return try decodeJSON(widest)
        } catch {
            firstError = error
        }

        if let balanced = Self.firstBalancedObject(in: widest), balanced.count < widest.count,
            let result = try? decodeJSON(balanced)
        {
            return result
        }
        throw .malformedJSON(reason: String(describing: firstError))
    }

    private func decodeJSON(_ text: Substring) throws -> ActionResult {
        let decoder = JSONDecoder()
        // JSON5 tolerates what small models emit most: trailing commas, single quotes, comments.
        decoder.allowsJSON5 = true
        return try decoder.decode(ActionResult.self, from: Data(text.utf8))
    }

    /// The first `{...}` whose braces balance, ignoring braces inside string literals.
    private static func firstBalancedObject(in text: Substring) -> Substring? {
        var depth = 0
        var inString = false
        var isEscaped = false
        var start: Substring.Index?
        for index in text.indices {
            let character = text[index]
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }
            switch character {
            case "\"":
                inString = true
            case "{":
                if depth == 0 { start = index }
                depth += 1
            case "}" where depth > 0:
                depth -= 1
                if depth == 0, let start { return text[start...index] }
            default:
                break
            }
        }
        return nil
    }

    // MARK: - Validation

    private func validate(_ result: ActionResult) throws(PipelineError) -> ActionResult {
        var result = result
        if result.type != .none, result.title.isEmpty { throw .missingTitle }
        if let date = result.date { result.date = try validDate(date) }
        if let time = result.time { result.time = try validTime(time) }
        if let amount = result.amount, amount < 0 { throw .negativeAmount(amount) }
        return result
    }

    /// "YYYY-MM-DD" that names a real day (no Feb 30).
    private func validDate(_ text: String) throws(PipelineError) -> String {
        guard let match = text.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
            let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
        else { throw .invalidDate(text) }

        let components = DateComponents(calendar: calendar, year: year, month: month, day: day)
        guard components.isValidDate else { throw .invalidDate(text) }
        return text
    }

    /// 24-hour "HH:mm". A one-digit hour ("9:30") is accepted and padded.
    private func validTime(_ text: String) throws(PipelineError) -> String {
        guard let match = text.wholeMatch(of: /(\d{1,2}):(\d{2})/),
            let hour = Int(match.1), let minute = Int(match.2),
            (0...23).contains(hour), (0...59).contains(minute)
        else { throw .invalidTime(text) }
        return String(format: "%02d:%02d", locale: Self.posix, hour, minute)
    }
}
