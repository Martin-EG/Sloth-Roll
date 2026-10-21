import Foundation
import Testing

@testable import SlothRoll

struct EventDraftTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    @Test func timedEventLastsOneHour() throws {
        let result = ActionResult(
            type: .event, title: "Feria del Libro", date: "2026-10-25", time: "18:00",
            location: "Teatro del Estado", confidence: .high)

        let draft = try EventDraft(result, calendar: calendar)

        let start = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 18)))
        #expect(draft.start == start)
        #expect(draft.end == start.addingTimeInterval(ActionsConfig.defaultEventDuration))
        #expect(!draft.isAllDay)
        #expect(draft.location == "Teatro del Estado")
        #expect(draft.title == "Feria del Libro")
    }

    @Test func noTimeMeansAllDay() throws {
        let result = ActionResult(type: .event, title: "Expo", date: "2026-10-25", confidence: .high)

        let draft = try EventDraft(result, calendar: calendar)

        #expect(draft.isAllDay)
        #expect(draft.start == calendar.date(from: DateComponents(year: 2026, month: 10, day: 25)))
    }

    @Test func noDateThrows() {
        let result = ActionResult(type: .event, title: "Expo", time: "18:00", confidence: .high)

        #expect(throws: ActionError.missingDate) { try EventDraft(result, calendar: calendar) }
    }

    @Test func impossibleDateThrows() {
        let result = ActionResult(type: .event, title: "Expo", date: "2026-02-30", confidence: .high)

        #expect(throws: ActionError.missingDate) { try EventDraft(result, calendar: calendar) }
    }

    @Test func dateAndTimeStringsRoundTrip() throws {
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 9, minute: 5)))

        #expect(ActionResult.dateString(from: date, calendar: calendar) == "2026-03-07")
        #expect(ActionResult.timeString(from: date, calendar: calendar) == "09:05")
    }
}
