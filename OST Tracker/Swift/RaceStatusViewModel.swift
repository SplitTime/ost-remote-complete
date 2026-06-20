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

func sortedField(_ efforts: [EffortRow], atSplit idx: Int, headers: [SplitHeader]) -> [EffortRow] {
    func groupRank(_ s: EffortStatus) -> Int {
        switch s {
        case .through:    return 0
        case .expected:   return 1
        case .dropped:    return 2
        case .notStarted: return 3
        }
    }
    let tagged = efforts.map { ($0, effortStatus($0, atSplit: idx, headers: headers)) }
    return tagged.sorted { lhs, rhs in
        let (le, ls) = lhs; let (re, rs) = rhs
        let lg = groupRank(ls), rg = groupRank(rs)
        if lg != rg { return lg < rg }
        switch (ls, rs) {
        case let (.through(la), .through(ra)):
            if la != ra { return la < ra }
            return le.bibNumber < re.bibNumber
        default:
            let lf = furthestSplitIndex(le), rf = furthestSplitIndex(re)
            if lf != rf { return lf > rf }
            return le.bibNumber < re.bibNumber
        }
    }.map { $0.0 }
}

func matchEfforts(_ query: String, in efforts: [EffortRow]) -> [EffortRow] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return [] }
    return efforts.filter {
        String($0.bibNumber).hasPrefix(q)
            || $0.firstName.lowercased().contains(q)
            || $0.lastName.lowercased().contains(q)
    }.sorted { $0.overallRank < $1.overallRank }
}
