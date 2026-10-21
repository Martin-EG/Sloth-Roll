import Foundation
import Testing

@testable import SlothRoll

struct ExtractionPromptTests {
    /// Tuesday 2026-10-20, noon in Mexico City.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()
    private static let today = calendar.date(
        from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))!

    /// Thursday 2026-07-16, 8 PM: a screenshot taken months before the scan.
    private static let capturedAt = calendar.date(
        from: DateComponents(year: 2026, month: 7, day: 16, hour: 20))!

    private let prompt = ExtractionPrompt(capturedAt: nil, today: today, calendar: calendar)

    @Test func withoutCaptureDateAnchorsToToday() {
        #expect(prompt.text.contains("Today is Tuesday / martes 2026-10-20."))
    }

    @Test func captureDateIsTheAnchorForRelativeDates() {
        let text = ExtractionPrompt(capturedAt: Self.capturedAt, today: Self.today, calendar: Self.calendar).text
        #expect(text.contains("This screenshot was taken on Thursday / jueves 2026-07-16."))
        #expect(text.contains("Friday / viernes 2026-07-17"))
        #expect(!text.contains("2026-10-20"))
    }

    @Test func typeIsTheFirstRequiredField() {
        #expect(prompt.text.contains("- \"type\": \"event\", \"place\", \"receipt\", or \"none\". Never leave it out."))
    }

    @Test func amountRuleExcludesOrderNumbers() {
        #expect(prompt.text.contains("Order, folio, booking, confirmation, ticket, seat, and phone numbers are NOT"))
    }

    @Test func listsUpcomingDaysForRelativeDates() {
        #expect(prompt.text.contains("Saturday / sábado 2026-10-24"))
        #expect(prompt.text.contains("Wednesday / miércoles 2026-10-21"))
    }

    @Test func endsWithReturnOnlyJSON() {
        #expect(prompt.text.hasSuffix(ExtractionPrompt.returnOnlyJSON))
    }

    @Test func exampleIsValidAndUsesThisSaturday() throws {
        let line = try #require(prompt.text.split(separator: "\n").first { $0.hasPrefix("{\"type\"") })
        let example = try ResultParser().parse(String(line))
        #expect(example.date == "2026-10-24")
        #expect(example.type == .event)
    }

    @Test func retryAddsReasonAndStrictReminder() {
        let retry = prompt.retryText(previousProblem: "no JSON object found")
        #expect(retry.hasPrefix(prompt.text))
        #expect(retry.contains("(no JSON object found)"))
        #expect(retry.contains("No markdown"))
    }
}
