import Foundation
import Testing

@testable import SlothRoll

struct ScreenshotItemTests {
    @Test func resultRoundTripsThroughStoredData() {
        let item = ScreenshotItem(assetID: "a", status: .triaged, capturedAt: nil)
        let result = ActionResult(
            type: .receipt, title: "OXXO", date: "2026-10-21", amount: Decimal(string: "249.50"),
            currency: .mxn, confidence: .high)

        item.result = result
        item.status = .extracted

        #expect(item.result == result)
        #expect(item.statusRaw == "extracted")
    }

    @Test func corruptStoredDataReadsAsNoResult() {
        let item = ScreenshotItem(assetID: "a", status: .extracted, capturedAt: nil)
        item.resultData = Data("{".utf8)

        #expect(item.result == nil)
    }
}
