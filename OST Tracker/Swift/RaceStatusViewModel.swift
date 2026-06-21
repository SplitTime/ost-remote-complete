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

    /// Weekday + 12-hour wall-clock in the event's zone, e.g. "Fri 9:08AM".
    /// Shown beside the elapsed time in both the runner and aid-station views.
    static func clockWithDay(_ t: Date, in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "EEE h:mma"
        return f.string(from: t)
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

// MARK: - Runner progress

struct RunnerStationLine {
    let label: String?
    let elapsed: String
    let timeOfDay: String
}
struct RunnerStationRow {
    let title: String
    let lines: [RunnerStationLine]
}
struct RunnerSummary {
    let name: String
    let bib: String
    let detail: String
}
struct RunnerProgress {
    let summary: RunnerSummary
    let rows: [RunnerStationRow]
}

func runnerProgress(_ e: EffortRow, spread: EventSpread) -> RunnerProgress {
    let start = spread.eventStartTime
    let tz = spread.eventTimeZone

    let statusWord = e.finished ? "Finished" : (e.dropped ? "Dropped" : "In progress")
    let summary = RunnerSummary(
        name: e.fullName,
        bib: String(e.bibNumber),
        detail: "Overall #\(e.overallRank) · Gender #\(e.genderRank) · \(statusWord)")

    let rows: [RunnerStationRow] = spread.splitHeaders.enumerated().map { idx, header in
        let subTimes = idx < e.absoluteTimes.count ? e.absoluteTimes[idx] : []
        let labels: [String?] = header.extensions.isEmpty ? [nil] : header.extensions.map { $0 }
        let lines: [RunnerStationLine] = labels.enumerated().map { k, label in
            let date = k < subTimes.count ? subTimes[k] : nil
            if let date = date {
                return RunnerStationLine(label: label,
                                         elapsed: RaceStatusFormat.elapsed(from: start, to: date),
                                         timeOfDay: "(\(RaceStatusFormat.clockWithDay(date, in: tz)))")
            }
            return RunnerStationLine(label: label, elapsed: "—", timeOfDay: "")
        }
        return RunnerStationRow(title: header.title, lines: lines)
    }
    return RunnerProgress(summary: summary, rows: rows)
}

// MARK: - Aid-station field

struct FieldRow {
    let bib: String
    let name: String
    let status: String
    let time: String
}
struct StationField {
    let countText: String
    let rows: [FieldRow]
}

/// The sub-split time at `sub` (0 = In, 1 = Out) for a split, or nil if absent.
private func subTime(_ e: EffortRow, atSplit idx: Int, sub: Int) -> Date? {
    guard idx >= 0, idx < e.absoluteTimes.count, sub < e.absoluteTimes[idx].count else { return nil }
    return e.absoluteTimes[idx][sub]
}

/// One runner's row at a station. In/Out stations show both times inline (no
/// "Through" word); a recorded In with no Out yet reads "still here". Plain
/// stations keep the single "Through" + time.
func fieldRow(_ e: EffortRow, status: EffortStatus, atSplit idx: Int,
              header: SplitHeader, start: Date, tz: TimeZone) -> FieldRow {
    func display(_ d: Date) -> String {
        "\(RaceStatusFormat.elapsed(from: start, to: d)) (\(RaceStatusFormat.clockWithDay(d, in: tz)))"
    }
    let statusText: String
    let timeText: String
    switch status {
    case .through(let arrival):
        if header.hasInOut {
            let inDate = subTime(e, atSplit: idx, sub: 0) ?? arrival
            let outPart = subTime(e, atSplit: idx, sub: 1).map { "Out \(display($0))" } ?? "still here"
            statusText = ""
            timeText = "In \(display(inDate))   \(outPart)"
        } else {
            statusText = "Through"
            timeText = display(arrival)
        }
    case .expected:
        statusText = "Expected"; timeText = ""
    case .dropped(let station):
        statusText = "Dropped @\(station)"; timeText = ""
    case .notStarted:
        statusText = "Not started"; timeText = ""
    }
    return FieldRow(bib: String(e.bibNumber), name: e.fullName,
                    status: statusText, time: timeText)
}

func stationField(splitIndex idx: Int, spread: EventSpread) -> StationField {
    let start = spread.eventStartTime
    let tz = spread.eventTimeZone
    let header = spread.splitHeaders[idx]
    let ordered = sortedField(spread.efforts, atSplit: idx, headers: spread.splitHeaders)
    let tagged = ordered.map { ($0, effortStatus($0, atSplit: idx, headers: spread.splitHeaders)) }
    let throughCount = tagged.filter { if case .through = $0.1 { return true } else { return false } }.count
    let rows = tagged.map { fieldRow($0.0, status: $0.1, atSplit: idx, header: header, start: start, tz: tz) }
    return StationField(countText: "\(throughCount) of \(spread.efforts.count) through",
                        rows: rows)
}
