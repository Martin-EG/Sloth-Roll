import Foundation
import Observation
import SwiftData

/// Drives the expense list: totals per currency and deleting an expense.
@Observable
@MainActor
final class ExpensesViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// One total per currency, in `Currency.allCases` order, unknown currency last.
    func totals(of expenses: [Expense]) -> [CurrencyTotal] {
        let sums = Dictionary(grouping: expenses, by: \.currency)
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.amount } }
        let order: [Currency?] = Currency.allCases.map(Optional.some) + [nil]
        return order.compactMap { currency in
            sums[currency].map { CurrencyTotal(currency: currency, amount: $0) }
        }
    }

    func amountText(_ amount: Decimal, currency: Currency?) -> String {
        Currency.format(amount, in: currency)
    }

    func delete(_ expense: Expense) {
        context.delete(expense)
        do {
            try context.save()
        } catch {
            Log.expenses.error("delete_failed error=\(String(describing: error), privacy: .public)")
        }
    }
}
