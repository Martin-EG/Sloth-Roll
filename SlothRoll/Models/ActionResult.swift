import Foundation

/// What the model read from one screenshot: the action to take and its details.
/// Decoding is forgiving (bad enum values become safe defaults); `ResultParser` validates.
struct ActionResult: Codable, Sendable, Equatable {
    var type: ActionType
    var title: String
    /// Calendar date as "YYYY-MM-DD".
    var date: String?
    /// 24-hour time as "HH:mm".
    var time: String?
    var location: String?
    var amount: Decimal?
    var currency: Currency?
    var confidence: Confidence

    init(
        type: ActionType, title: String, date: String? = nil, time: String? = nil,
        location: String? = nil, amount: Decimal? = nil, currency: Currency? = nil,
        confidence: Confidence
    ) {
        self.type = type
        self.title = title
        self.date = date
        self.time = time
        self.location = location
        self.amount = amount
        self.currency = currency
        self.confidence = confidence
    }

    private enum CodingKeys: String, CodingKey {
        case type, title, date, time, location, amount, currency, confidence
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decodeIfPresent(ActionType.self, forKey: .type)) ?? ActionType.none
        title = container.lenientString(forKey: .title) ?? ""
        date = container.lenientString(forKey: .date)
        time = container.lenientString(forKey: .time)
        location = container.lenientString(forKey: .location)
        amount = container.lenientDecimal(forKey: .amount)
        currency = container.lenientString(forKey: .currency).flatMap(Currency.init(lenient:))
        confidence = (try? container.decodeIfPresent(Confidence.self, forKey: .confidence)) ?? .low
    }

    /// Writes every key, with `null` for missing values, so the output matches the prompt schema.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(time, forKey: .time)
        try container.encode(location, forKey: .location)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(confidence, forKey: .confidence)
    }
}

extension KeyedDecodingContainer {
    /// Trimmed string, or nil when missing, not a string, empty, or a spelled-out null.
    fileprivate func lenientString(forKey key: Key) -> String? {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let nullWords: Set<String> = ["", "null", "none", "n/a", "na", "-"]
        return nullWords.contains(trimmed.lowercased()) ? nil : trimmed
    }

    /// A number, or a string like "$1,249.50" reduced to its digits; nil otherwise.
    fileprivate func lenientDecimal(forKey key: Key) -> Decimal? {
        if let number = try? decodeIfPresent(Decimal.self, forKey: key) { return number }
        guard let raw = lenientString(forKey: key) else { return nil }
        let cleaned = raw.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
