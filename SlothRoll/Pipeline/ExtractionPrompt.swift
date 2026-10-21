import Foundation

/// Builds the bilingual (Spanish/English) extraction prompt, anchored to the day the
/// screenshot was taken (or today if unknown) so "hoy", "mañana" or "este sábado" resolve
/// to real days.
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

    /// The day relative dates are counted from.
    private let anchor: Date
    private let anchorIsCapture: Bool
    private let calendar: Calendar

    /// `capturedAt` comes from Photos; when it's nil, relative dates count from `today`.
    /// `calendar` decides the user's time zone, so days are the user's local days.
    init(capturedAt: Date?, today: Date, calendar: Calendar = .current) {
        self.anchor = capturedAt ?? today
        self.anchorIsCapture = capturedAt != nil
        self.calendar = calendar
    }

    /// The first-attempt prompt.
    var text: String {
        """
        You read one phone screenshot. It may be in Spanish or English. Extract the single most \
        useful action from it.

        \(anchorSentence)
        The days after it: \(upcomingDays()).
        Resolve relative dates ("hoy", "today", "mañana", "tomorrow", "este sábado", \
        "next Friday", "el próximo lunes") from that day using these dates. If a date shows \
        no year, use the first matching date on or after that day.

        "type" is required and is one of:
        - "event": something that happens at a date or time (concert, meeting, cita, \
        reservation, flight, class).
        - "place": a restaurant, shop, venue, or address worth saving, with no specific date.
        - "receipt": a purchase, payment, transfer, or bill with an amount (ticket, recibo, \
        comprobante, factura).
        - "none": anything else (memes, chats, settings, photos, home screens).

        Fields (always include all eight keys, in this order):
        - "type": "event", "place", "receipt", or "none". Never leave it out.
        - "title": short, at most 6 words, in the screenshot's language.
        - "date": "YYYY-MM-DD" or null.
        - "time": 24-hour "HH:mm" or null. Convert AM/PM: "08:25 PM" is "20:25", \
        "12:30 a. m." is "00:30".
        - "location": venue name or address, or null.
        - "amount": money only: a price or total shown with "$", "MXN", "USD", "Total", \
        "Importe", "Pagado", or "Precio". Write it as a plain number (249.50), no symbols or \
        commas. Order, folio, booking, confirmation, ticket, seat, and phone numbers are NOT \
        amounts. If no price is shown, use null.
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

    private var anchorSentence: String {
        anchorIsCapture
            ? "This screenshot was taken on \(dayLabel(anchor)). That day is \"hoy\" / \"today\"."
            : "Today is \(dayLabel(anchor))."
    }

    /// One line of valid output, dated the Saturday after the anchor so it matches the list.
    private var example: String {
        let saturday =
            calendar.nextDate(
                after: anchor, matching: DateComponents(weekday: Self.saturday),
                matchingPolicy: .nextTime) ?? anchor
        return """
            {"type":"event","title":"Noche de jazz","date":"\(isoDate(saturday))",\
            "time":"21:00","location":"Blue Room, Roma Norte","amount":null,"currency":null,\
            "confidence":"high"}
            """
    }

    private func upcomingDays() -> String {
        (1...PipelineConfig.promptCalendarDays)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
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
