import Foundation

/// Sum of the expenses in one currency (nil: receipts that didn't say).
struct CurrencyTotal: Equatable, Identifiable {
    let currency: Currency?
    let amount: Decimal

    var id: String { currency?.rawValue ?? "unknown" }
}
