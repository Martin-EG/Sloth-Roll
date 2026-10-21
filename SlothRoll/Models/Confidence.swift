/// How sure the model is about its reading. Unknown values decode as `.low`.
enum Confidence: String, Codable, Sendable, CaseIterable {
    case low, medium, high

    /// Accepts any casing and surrounding spaces.
    init?(lenient raw: String) {
        self.init(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    init(from decoder: any Decoder) throws {
        let raw = try? decoder.singleValueContainer().decode(String.self)
        self = raw.flatMap(Confidence.init(lenient:)) ?? .low
    }
}
