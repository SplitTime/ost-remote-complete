import Foundation

/// Pure presentation helpers for the live reads list. Kept free of UIKit and
/// global state so the formatting rules are unit-testable.
enum LiveReadsFormat {

    /// Race-local wall clock (`HH:mm:ss`) for one read.
    ///
    /// `entered_time` is preferred because it already carries the operator's
    /// race-local clock — but its format varies by source (a bare `10:42:03`
    /// from some tools, a full `2022-07-12 23:58:28-6:00` from the app). We
    /// normalize by pulling out the time-of-day. When `entered_time` is missing
    /// we render the canonical UTC `absolute_time` in `zone`. `—` when neither
    /// is usable.
    static func clock(enteredTime: String?, absoluteTime: String?, zone: TimeZone = .current) -> String {
        if let entered = enteredTime, let hms = firstClock(in: entered) {
            return hms
        }
        if let absolute = absoluteTime, let date = absoluteParser.date(from: absolute) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = zone
            f.dateFormat = "HH:mm:ss"
            return f.string(from: date)
        }
        return "—"
    }

    /// Title line for a read: the bib, plus the runner's name when it could be
    /// resolved from the local roster. Falls back to the bare bib when the name
    /// is missing or blank (e.g. an unmatched read).
    static func nameLine(bib: String, name: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "#\(bib)" : "#\(bib)  \(trimmed)"
    }

    /// Human-readable label for a read's `source`. Reads from this device →
    /// "This app"; any other `ost-remote` device → "Remote device"; everything
    /// else passes through verbatim (e.g. "Rake Task"). Empty when missing.
    static func friendlySource(_ raw: String?, myUUID: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "" }
        guard raw == "ost-remote" || raw.hasPrefix("ost-remote-") else { return raw }
        let uuid = raw == "ost-remote" ? "" : String(raw.dropFirst("ost-remote-".count))
        if let myUUID = myUUID, !uuid.isEmpty, uuid == myUUID { return "This app" }
        return "Remote device"
    }

    // MARK: - Helpers

    /// First `HH:mm:ss` substring (the time-of-day), ignoring date and offset.
    private static func firstClock(in s: String) -> String? {
        guard let r = s.range(of: "[0-9]{2}:[0-9]{2}:[0-9]{2}", options: .regularExpression) else { return nil }
        return String(s[r])
    }

    private static let absoluteParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
