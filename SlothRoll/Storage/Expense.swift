import Foundation
import SwiftData

/// One expense saved from a receipt screenshot. Stays in the app (no export in the MVP).
@Model
final class Expense {
    var title: String
    var amount: Decimal
    /// Raw `Currency`; nil when the receipt didn't say.
    var currencyRaw: String?
    /// Day of the purchase.
    var date: Date
    /// `PHAsset.localIdentifier` of the receipt screenshot.
    var sourceAssetID: String
    var createdAt: Date

    init(
        title: String, amount: Decimal, currency: Currency?, date: Date, sourceAssetID: String,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.amount = amount
        self.currencyRaw = currency?.rawValue
        self.date = date
        self.sourceAssetID = sourceAssetID
        self.createdAt = createdAt
    }

    var currency: Currency? {
        get { currencyRaw.flatMap(Currency.init(rawValue:)) }
        set { currencyRaw = newValue?.rawValue }
    }
}
