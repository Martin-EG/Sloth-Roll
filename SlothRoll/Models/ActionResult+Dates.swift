import Foundation

/// Converts the result's "YYYY-MM-DD" / "HH:mm" strings to and from `Date` in a given calendar.
extension ActionResult {
    /// Start of the result's day, or nil when there is no date or it isn't "YYYY-MM-DD".
    func day(in calendar: Calendar = .current) -> Date? {
        guard let date, let match = date.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
            let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }

    /// The result's day at its time, or nil when either is missing or malformed.
    func dayAndTime(in calendar: Calendar = .current) -> Date? {
        guard let day = day(in: calendar), let (hour, minute) = hourAndMinute else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// Hour and minute from "HH:mm", or nil.
    var hourAndMinute: (Int, Int)? {
        guard let time, let match = time.wholeMatch(of: /(\d{1,2}):(\d{2})/),
            let hour = Int(match.1), let minute = Int(match.2),
            (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return (hour, minute)
    }

    /// "YYYY-MM-DD" for the day `date` falls on.
    static func dateString(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"),
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// "HH:mm" (24-hour) for `date`.
    static func timeString(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(
            format: "%02d:%02d", locale: Locale(identifier: "en_US_POSIX"),
            parts.hour ?? 0, parts.minute ?? 0)
    }
}
