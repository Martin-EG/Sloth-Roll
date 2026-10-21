import Foundation

/// Builds the bilingual (Spanish/English) extraction prompt, anchored to today's date so
/// relative dates like "este sábado" or "tomorrow" resolve to real days.
struct ExtractionPrompt: Sendable {
    static let returnOnlyJSON = "Return ONLY the JSON object, no extra text."

    private static let englishWeekdays = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]
    private static let spanishWeekdays = [
        "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado",
    ]
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let saturday = 7

    private let today: Date
    private let calendar: Calendar

    /// `calendar` decides the user's time zone, so "today" is the user's local day.
    init(today: Date, calendar: Calendar = .current) {
        self.today = today
        self.calendar = calendar
    }

    /// The first-attempt prompt.
    var text: String {
        """
        You read one phone screenshot. It may be in Spanish or English. Extract the single most \
        useful action from it.

        Today is \(dayLabel(today)).
        Upcoming days: \(upcomingDays()).
        Resolve relative dates ("mañana", "tomorrow", "este sábado", "next Friday", \
        "el próximo lunes") with these dates. If no year is shown, use the next date that \
        has not passed.

        type is one of:
        - "event": something that happens at a date or time (concert, meeting, cita, \
        reservation, flight, class).
        - "place": a restaurant, shop, venue, or address worth saving, with no specific date.
        - "receipt": a purchase, payment, transfer, or bill with an amount (ticket, recibo, \
        comprobante, factura).
        - "none": anything else (memes, chats, settings, photos, home screens).

        Fields:
        - "title": short, at most 6 words, in the screenshot's language.
        - "date": "YYYY-MM-DD" or null. "time": 24-hour "HH:mm" or null.
        - "location": venue name or address, or null.
        - "amount": the final total as a plain number (249.50), or null. No symbols or commas.
        - "currency": "MXN", "USD", or null. A bare "$" on a Mexican screenshot means "MXN".
        - "confidence": "low", "medium", or "high".

        Example:
        \(example)

        \(Self.returnOnlyJSON)
        """
    }

    /// The retry prompt: the same instructions plus a blunt reminder about the format.
    func retryText(previousProblem: String) -> String {
        """
        \(text)

        Your previous answer could not be used (\(previousProblem)). Reply with exactly one \
        JSON object that starts with { and ends with }. Use null for unknown fields. No \
        markdown, no code fences, no explanation.
        """
    }

    // MARK: - Private

    /// One line of valid output, dated this coming Saturday so it matches the date list.
    private var example: String {
        let saturday =
            calendar.nextDate(
                after: today, matching: DateComponents(weekday: Self.saturday),
                matchingPolicy: .nextTime) ?? today
        return """
            {"type":"event","title":"Noche de jazz","date":"\(isoDate(saturday))",\
            "time":"21:00","location":"Blue Room, Roma Norte","amount":null,"currency":null,\
            "confidence":"high"}
            """
    }

    private func upcomingDays() -> String {
        (1...PipelineConfig.promptCalendarDays)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .map(dayLabel)
            .joined(separator: "; ")
    }

    /// "Tuesday / martes 2026-10-20"
    private func dayLabel(_ date: Date) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        return "\(Self.englishWeekdays[index]) / \(Self.spanishWeekdays[index]) \(isoDate(date))"
    }

    private func isoDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", locale: Self.posix,
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
