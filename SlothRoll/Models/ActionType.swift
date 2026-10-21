/// What a screenshot turns into. Unknown values from the model decode as `.none`.
enum ActionType: String, Codable, Sendable, CaseIterable {
    case event, place, receipt, none

    /// Accepts any casing, surrounding spaces, and the Spanish names (evento, lugar, recibo).
    init?(lenient raw: String) {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "evento": self = .event
        case "lugar": self = .place
        case "recibo": self = .receipt
        default: self.init(rawValue: key)
        }
    }

    init(from decoder: any Decoder) throws {
        let raw = try? decoder.singleValueContainer().decode(String.self)
        self = raw.flatMap(ActionType.init(lenient:)) ?? ActionType.none
    }
}
