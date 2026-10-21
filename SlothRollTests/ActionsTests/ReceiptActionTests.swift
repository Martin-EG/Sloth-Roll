import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct ReceiptActionTests {
    private let container = Persistence.makeContainer(inMemory: true)

    private func expenses() throws -> [Expense] {
        try container.mainContext.fetch(FetchDescriptor<Expense>())
    }

    @Test func savesAnExpense() async throws {
        let action = ReceiptAction(context: container.mainContext)
        let result = ActionResult(
            type: .receipt, title: "OXXO", date: "2026-10-21", amount: Decimal(string: "249.50"),
            currency: .mxn, confidence: .high)

        let outcome = try await action.perform(result, assetID: "r1")

        let saved = try #require(try expenses().first)
        #expect(saved.title == "OXXO")
        #expect(saved.amount == Decimal(string: "249.50"))
        #expect(saved.currency == .mxn)
        #expect(saved.sourceAssetID == "r1")
        #expect(outcome.message.hasPrefix("Saved expense: OXXO"))
    }

    @Test func undatedReceiptUsesScreenshotDate() async throws {
        let captured = Date(timeIntervalSince1970: 1_700_000_000)
        container.mainContext.insert(
            ScreenshotItem(assetID: "r2", status: .extracted, capturedAt: captured))
        let action = ReceiptAction(context: container.mainContext)
        let result = ActionResult(type: .receipt, title: "Café", amount: 45, confidence: .medium)

        _ = try await action.perform(result, assetID: "r2")

        #expect(try expenses().first?.date == captured)
    }

    @Test(arguments: [nil, Decimal.zero])
    func missingOrZeroAmountThrowsAndSavesNothing(amount: Decimal?) async throws {
        let action = ReceiptAction(context: container.mainContext)
        let result = ActionResult(type: .receipt, title: "OXXO", amount: amount, confidence: .low)

        await #expect(throws: ActionError.missingAmount) {
            try await action.perform(result, assetID: "r3")
        }
        #expect(try expenses().isEmpty)
    }
}
