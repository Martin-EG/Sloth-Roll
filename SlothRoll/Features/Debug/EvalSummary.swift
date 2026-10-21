#if DEBUG
/// Totals for an eval run: type counts, timings, accuracy, and how the OCR triage would do.
struct EvalSummary: Sendable, Equatable {
    let total: Int
    let countsByType: [ActionType: Int]
    let fallbackCount: Int
    let retryCount: Int
    let averageExtraction: Duration?
    let averageOCR: Duration?

    let markedCount: Int
    let correctCount: Int

    /// Rows OCR found too little text in (below the triage threshold).
    let noTextCount: Int
    /// Marked rows whose right answer is `.none` (junk).
    let markedJunkCount: Int
    /// Junk rows triage would drop.
    let junkWithoutText: Int
    /// Real actions triage would wrongly drop.
    let actionableWithoutText: Int

    var accuracy: Double? {
        markedCount > 0 ? Double(correctCount) / Double(markedCount) : nil
    }

    init(rows: [EvalRow]) {
        total = rows.count
        countsByType = Dictionary(grouping: rows, by: \.report.result.type).mapValues(\.count)
        fallbackCount = rows.count(where: { $0.report.usedFallback })
        retryCount = rows.count(where: { $0.report.attempts > 1 })
        averageExtraction = Self.average(rows.map(\.report.duration))
        averageOCR = Self.average(rows.map(\.textScan.duration))

        let marked = rows.filter { $0.mark != nil }
        markedCount = marked.count
        correctCount = marked.count(where: { $0.mark == .correct })

        noTextCount = rows.count(where: { !$0.textScan.hasText })
        let junk = marked.filter { $0.expectedType == ActionType.none }
        markedJunkCount = junk.count
        junkWithoutText = junk.count(where: { !$0.textScan.hasText })
        actionableWithoutText = marked.count(where: {
            $0.expectedType != ActionType.none && !$0.textScan.hasText
        })
    }

    private static func average(_ durations: [Duration]) -> Duration? {
        guard !durations.isEmpty else { return nil }
        return durations.reduce(.zero, +) / durations.count
    }
}
#endif
