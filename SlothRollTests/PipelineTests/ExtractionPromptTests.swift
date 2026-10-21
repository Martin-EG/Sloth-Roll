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

    private let prompt = ExtractionPrompt(today: today, calendar: calendar)

    @Test func includesTodayWithWeekdayInBothLanguages() {
        #expect(prompt.text.contains("Today is Tuesday / martes 2026-10-20."))
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
