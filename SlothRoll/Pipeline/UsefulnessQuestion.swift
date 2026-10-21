/// The extra yes/no question the extraction model answers about leftover screenshots, and a
/// forgiving reader for its answer.
enum UsefulnessQuestion {
    static let prompt = "Is this screenshot still useful to keep? Answer only yes or no."

    /// True for yes, false for no, nil when the answer has neither. The first yes or no word
    /// wins, so "No." and "Answer: yes" both read; Spanish "sí" counts as yes.
    static func parse(_ answer: String) -> Bool? {
        answer.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .lazy
            .compactMap { word -> Bool? in
                switch word {
                case "yes", "sí", "si": true
                case "no": false
                default: nil
                }
            }
            .first
    }
}
