import Foundation

/// Why an action couldn't run. Every case has a message the UI can show as is.
enum ActionError: LocalizedError, Equatable, Sendable {
    case calendarAccessDenied
    case missingDate
    case missingLocation
    case missingAmount
    case mapsUnavailable
    case saveFailed(reason: String)
    /// The card's type has no action (e.g. "none").
    case unsupported(ActionType)

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            "Sloth Roll can't add events. Allow Calendars access in Settings › Apps › Sloth Roll."
        case .missingDate:
            "This event has no date. Tap the card to add one."
        case .missingLocation:
            "This place has no address. Tap the card to add one."
        case .missingAmount:
            "This receipt has no amount. Tap the card to add one."
        case .mapsUnavailable:
            "Couldn't open Maps."
        case .saveFailed:
            "Couldn't save it. Try again."
        case .unsupported:
            "Nothing to do for this one."
        }
    }
}
