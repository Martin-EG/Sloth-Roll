import Foundation

/// Money formatting shared by the actions and the expense list.
extension Currency {
    /// Currency-formatted in the user's locale ("MX$249.50"), or a plain two-decimal number
    /// when the currency is unknown.
    static func format(_ amount: Decimal, in currency: Currency?) -> String {
        guard let currency else { return amount.formatted(.number.precision(.fractionLength(2))) }
        return amount.formatted(.currency(code: currency.rawValue))
    }
}
