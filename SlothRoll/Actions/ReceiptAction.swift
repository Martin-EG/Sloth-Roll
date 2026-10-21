import Foundation
import SwiftData

/// Saves a receipt as an in-app `Expense` (no export in the MVP).
@MainActor
final class ReceiptAction: ActionPerformer {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func perform(_ result: ActionResult, assetID: String) async throws -> ActionOutcome {
        guard let amount = result.amount, amount > 0 else { throw ActionError.missingAmount }
        let title = result.title.isEmpty ? "Expense" : result.title
        let expense = Expense(
            title: title, amount: amount, currency: result.currency,
            date: result.day(in: calendar) ?? capturedAt(assetID) ?? Date(),
            sourceAssetID: assetID)
        context.insert(expense)
        do {
            try context.save()
        } catch {
            context.delete(expense)
            Log.actions.error("expense_save_failed error=\(String(describing: error), privacy: .public)")
            throw ActionError.saveFailed(reason: String(describing: error))
        }
        Log.actions.info("expense_added")

        let money = Currency.format(amount, in: result.currency)
        return ActionOutcome(message: "Saved expense: \(title), \(money)")
    }

    /// When the screenshot was taken: a receipt with no date is dated by its screenshot.
    private func capturedAt(_ assetID: String) -> Date? {
        var descriptor = FetchDescriptor<ScreenshotItem>(
            predicate: #Predicate { $0.assetID == assetID })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.capturedAt
    }
}
