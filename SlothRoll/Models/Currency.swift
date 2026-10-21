/// Currencies the MVP understands. Anything else decodes as no currency.
enum Currency: String, Codable, Sendable, CaseIterable {
    case mxn = "MXN"
    case usd = "USD"

    /// Accepts any casing and common spellings ("MX$", "pesos", "US$", "dollars").
    init?(lenient raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "MXN", "MX$", "MN", "PESO", "PESOS": self = .mxn
        case "USD", "US$", "DOLLAR", "DOLLARS", "DÓLARES", "DOLARES": self = .usd
        default: return nil
        }
    }
}
