import Foundation

/// Pure formatting for race-status times. No UIKit, no global state.
enum RaceStatusFormat {

    /// Elapsed since `start` as `H:MM`; hours are unbounded (race can exceed a day).
    static func elapsed(from start: Date, to t: Date) -> String {
        let seconds = t.timeIntervalSince(start)
        guard seconds >= 0 else { return "—" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }

    static func timeOfDay(_ t: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: t)
    }

    static func dayOffset(from start: Date, to t: Date, in tz: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let a = cal.startOfDay(for: start)
        let b = cal.startOfDay(for: t)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }
}
