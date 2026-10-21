import Foundation

/// Plain-words text for a review card: the action's name, label, icon, and proposal line.
enum CardText {
    /// "Add event", "Open in Maps", "Add expense".
    static func actionName(_ type: ActionType) -> String {
        switch type {
        case .event: "Add event"
        case .place: "Open in Maps"
        case .receipt: "Add expense"
        case .none: "Nothing to do"
        }
    }

    static func typeLabel(_ type: ActionType) -> String {
        switch type {
        case .event: "Event"
        case .place: "Place"
        case .receipt: "Receipt"
        case .none: "Other"
        }
    }

    static func systemImage(_ type: ActionType) -> String {
        switch type {
        case .event: "calendar"
        case .place: "mappin.and.ellipse"
        case .receipt: "receipt"
        case .none: "questionmark"
        }
    }

    /// "Add event · Sat 25 Oct, 18:00 · Teatro del Estado", in the user's locale.
    static func proposal(_ result: ActionResult, calendar: Calendar = .current) -> String {
        var parts = [actionName(result.type)]
        switch result.type {
        case .event:
            parts.append(when(result, calendar: calendar) ?? "no date")
            if let location = result.location { parts.append(location) }
        case .place:
            if let location = result.location { parts.append(location) }
        case .receipt:
            parts.append(result.amount.map { Currency.format($0, in: result.currency) } ?? "no amount")
            if let day = result.day(in: calendar) { parts.append(shortDay(day)) }
        case .none:
            break
        }
        return parts.joined(separator: " · ")
    }

    /// "Sat 25 Oct, 18:00", or just the day when there's no time.
    private static func when(_ result: ActionResult, calendar: Calendar) -> String? {
        guard let day = result.day(in: calendar) else { return nil }
        guard let start = result.dayAndTime(in: calendar) else { return shortDay(day) }
        return shortDay(day) + ", " + start.formatted(.dateTime.hour().minute())
    }

    private static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
