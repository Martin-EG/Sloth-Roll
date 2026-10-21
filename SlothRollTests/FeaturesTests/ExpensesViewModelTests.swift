import Foundation
import SwiftData
import Testing

@testable import SlothRoll

@MainActor
struct ExpensesViewModelTests {
    private let container = Persistence.makeContainer(inMemory: true)

    @Test func totalsGroupByCurrencyUnknownLast() {
        let viewModel = ExpensesViewModel(context: container.mainContext)
        let expenses = [
            Expense(title: "a", amount: 10, currency: .usd, date: .now, sourceAssetID: "1"),
            Expense(title: "b", amount: 100, currency: .mxn, date: .now, sourceAssetID: "2"),
            Expense(title: "c", amount: Decimal(string: "0.5")!, currency: .usd, date: .now, sourceAssetID: "3"),
            Expense(title: "d", amount: 7, currency: nil, date: .now, sourceAssetID: "4"),
        ]

        #expect(
            viewModel.totals(of: expenses) == [
                CurrencyTotal(currency: .mxn, amount: 100),
                CurrencyTotal(currency: .usd, amount: Decimal(string: "10.5")!),
                CurrencyTotal(currency: nil, amount: 7),
            ])
    }
}
