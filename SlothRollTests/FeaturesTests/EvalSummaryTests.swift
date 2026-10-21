import Foundation
import Testing

@testable import SlothRoll

struct EvalSummaryTests {
    private func row(
        _ type: ActionType, seconds: Int, characters: Int, mark: EvalMark?, attempts: Int = 1
    ) -> EvalRow {
        EvalRow(
            assetID: UUID().uuidString, thumbnail: nil, capturedAt: nil,
            report: ExtractionReport(
                result: ActionResult(type: type, title: "t", confidence: .high),
                attempts: attempts, rawOutputs: [], problems: [], usedFallback: false,
                duration: .seconds(seconds)),
            textScan: TextScan(
                lineCount: characters > 0 ? 1 : 0, characterCount: characters, text: "",
                duration: .milliseconds(100)),
            mark: mark)
    }

    @Test func countsTimesAccuracyAndTriage() {
        let rows = [
            row(.event, seconds: 4, characters: 120, mark: .correct),
            row(.receipt, seconds: 6, characters: 300, mark: .wrong(expected: .event), attempts: 2),
            row(.none, seconds: 2, characters: 0, mark: .correct),  // junk, no text
            row(.none, seconds: 4, characters: 40, mark: .correct),  // junk with text (meme)
            row(.place, seconds: 4, characters: 0, mark: nil),  // unmarked
        ]

        let summary = EvalSummary(rows: rows)

        #expect(summary.total == 5)
        #expect(summary.countsByType[.none] == 2)
        #expect(summary.countsByType[.event] == 1)
        #expect(summary.averageExtraction == .seconds(4))
        #expect(summary.retryCount == 1)
        #expect(summary.markedCount == 4)
        #expect(summary.correctCount == 3)
        #expect(summary.accuracy == 0.75)
        #expect(summary.noTextCount == 2)
        #expect(summary.markedJunkCount == 2)
        #expect(summary.junkWithoutText == 1)
        #expect(summary.actionableWithoutText == 0)
    }
}
