import Foundation

/// The calendar event a result describes, before it touches EventKit (so it can be tested).
struct EventDraft: Equatable, Sendable {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?

    /// All-day when the result has no time; otherwise `ActionsConfig.defaultEventDuration` long.
    init(_ result: ActionResult, calendar: Calendar = .current) throws(ActionError) {
        guard let day = result.day(in: calendar) else { throw .missingDate }
        title = result.title
        location = result.location
        if let start = result.dayAndTime(in: calendar) {
            self.start = start
            end = start.addingTimeInterval(ActionsConfig.defaultEventDuration)
            isAllDay = false
        } else {
            start = day
            end = day
            isAllDay = true
        }
    }
}
