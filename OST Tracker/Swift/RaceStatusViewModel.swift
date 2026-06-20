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

/// Per-station classification of an effort, used by the aid-station view.
enum EffortStatus: Equatable {
    case through(arrival: Date)
    case expected
    case dropped(atStation: String)
    case notStarted
}

/// Highest split index with any recorded sub-split time, or -1 if none.
func furthestSplitIndex(_ e: EffortRow) -> Int {
    for idx in stride(from: e.absoluteTimes.count - 1, through: 0, by: -1) {
        if e.absoluteTimes[idx].contains(where: { $0 != nil }) { return idx }
    }
    return -1
}

/// Arrival time at a split = its first non-nil sub-split (the "In" time).
private func arrivalTime(_ e: EffortRow, atSplit idx: Int) -> Date? {
    guard idx >= 0, idx < e.absoluteTimes.count else { return nil }
    return e.absoluteTimes[idx].compactMap { $0 }.first
}

func effortStatus(_ e: EffortRow, atSplit idx: Int, headers: [SplitHeader]) -> EffortStatus {
    if let arrival = arrivalTime(e, atSplit: idx) { return .through(arrival: arrival) }
    let furthest = furthestSplitIndex(e)
    if e.dropped {
        let station = (furthest >= 0 && furthest < headers.count) ? headers[furthest].title : "—"
        return .dropped(atStation: station)
    }
    return furthest >= 0 ? .expected : .notStarted
}
