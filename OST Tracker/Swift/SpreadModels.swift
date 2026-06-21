import Foundation

/// Domain value parsed from `GET events/{slug}/spread`. Pure data — no UIKit.
/// `Decodable` walks the JSON:API envelope (`data` + `included`) and converts the
/// raw ISO strings into `Date` / `TimeZone` up front so presentation code never
/// touches strings.
struct EventSpread: Decodable {
    let name: String
    let courseName: String
    let displayStyle: String
    let eventStartTime: Date
    let eventTimeZone: TimeZone
    let splitHeaders: [SplitHeader]
    let efforts: [EffortRow]

    init(from decoder: Decoder) throws {
        let env = try RawEnvelope(from: decoder)
        let attrs = env.data.attributes
        name = attrs.name
        courseName = attrs.courseName ?? ""
        displayStyle = attrs.displayStyle ?? ""
        eventTimeZone = SpreadDate.timeZone(from: attrs.eventStartTime)
        eventStartTime = SpreadDate.parse(attrs.eventStartTime) ?? Date(timeIntervalSince1970: 0)
        splitHeaders = attrs.splitHeaderData.map {
            SplitHeader(title: $0.title, splitName: $0.splitName,
                        distanceMeters: $0.distance ?? 0, extensions: $0.extensions ?? [],
                        lap: $0.lap ?? 1)
        }
        efforts = (env.included ?? [])
            .filter { $0.type == "effortTimesRows" }
            .map { EffortRow(raw: $0.attributes) }
    }

    static func decode(from data: Data) throws -> EventSpread {
        try JSONDecoder().decode(EventSpread.self, from: data)
    }
}

struct SplitHeader {
    let title: String
    let splitName: String
    let distanceMeters: Double
    let extensions: [String]
    let lap: Int

    var hasInOut: Bool { extensions.count > 1 }
}

struct EffortRow {
    let overallRank: Int
    let genderRank: Int
    let bibNumber: Int
    let firstName: String
    let lastName: String
    let gender: String
    let age: Int?
    let flexibleGeolocation: String?
    let stopped: Bool
    let dropped: Bool
    let finished: Bool
    /// Aligned by index to `EventSpread.splitHeaders`; inner array is the
    /// sub-splits (1 for a plain station, 2 = In/Out). `nil` == no time.
    let absoluteTimes: [[Date?]]

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    fileprivate init(raw: RawEffort) {
        overallRank = raw.overallRank ?? Int.max
        genderRank = raw.genderRank ?? Int.max
        bibNumber = raw.bibNumber ?? 0
        firstName = raw.firstName ?? ""
        lastName = raw.lastName ?? ""
        gender = raw.gender ?? ""
        age = raw.age
        flexibleGeolocation = raw.flexibleGeolocation
        stopped = raw.stopped ?? false
        dropped = raw.dropped ?? false
        finished = raw.finished ?? false
        absoluteTimes = (raw.absoluteTimes ?? []).map { $0.map { SpreadDate.parse($0) } }
    }

    init(overallRank: Int, genderRank: Int, bibNumber: Int,
         firstName: String, lastName: String, gender: String = "", age: Int? = nil,
         flexibleGeolocation: String? = nil, stopped: Bool = false,
         dropped: Bool = false, finished: Bool = false, absoluteTimes: [[Date?]]) {
        self.overallRank = overallRank; self.genderRank = genderRank
        self.bibNumber = bibNumber; self.firstName = firstName; self.lastName = lastName
        self.gender = gender; self.age = age; self.flexibleGeolocation = flexibleGeolocation
        self.stopped = stopped; self.dropped = dropped; self.finished = finished
        self.absoluteTimes = absoluteTimes
    }
}

// `SplitHeader` has no explicit init, so its synthesized memberwise initializer
// `init(title:splitName:distanceMeters:extensions:lap:)` is used by both the
// decoder above and the tests — do NOT add another init (it would redeclare it).

/// One event in an event group, used to populate the event selector.
struct EventRef {
    let slug: String
    let name: String
}

// MARK: - Date / timezone parsing

enum SpreadDate {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        return fractional.date(from: s) ?? plain.date(from: s)
    }

    /// Reads the trailing UTC offset (`Z` or `±HH:MM`) so wall-clock times can be
    /// shown in the event's local zone.
    static func timeZone(from s: String) -> TimeZone {
        if s.hasSuffix("Z") { return TimeZone(secondsFromGMT: 0) ?? .current }
        let tail = String(s.suffix(6)) // e.g. "-06:00"
        guard tail.count == 6, tail.contains(":"),
              let signChar = tail.first, signChar == "+" || signChar == "-",
              let hours = Int(tail.dropFirst().prefix(2)), let minutes = Int(tail.suffix(2)) else {
            return .current
        }
        // Sign must come from the leading character, not the parsed hour: a
        // "-00:30" offset has hours == 0, so inferring the sign from the hour
        // would wrongly treat it as positive.
        let sign = signChar == "-" ? -1 : 1
        return TimeZone(secondsFromGMT: sign * (hours * 3600 + minutes * 60)) ?? .current
    }
}

// MARK: - Raw JSON:API envelope (private to this file)

private struct RawEnvelope: Decodable {
    let data: RawData
    let included: [RawEffortResource]?
}
private struct RawData: Decodable { let attributes: RawSpreadAttributes }
private struct RawSpreadAttributes: Decodable {
    let name: String
    let courseName: String?
    let displayStyle: String?
    let eventStartTime: String
    let splitHeaderData: [RawSplitHeader]
}
private struct RawSplitHeader: Decodable {
    let title: String
    let splitName: String
    let distance: Double?
    let extensions: [String]?
    let lap: Int?
    enum CodingKeys: String, CodingKey {
        case title, distance, extensions, lap
        case splitName = "split_name"
    }
}
private struct RawEffortResource: Decodable { let type: String; let attributes: RawEffort }
private struct RawEffort: Decodable {
    let overallRank: Int?
    let genderRank: Int?
    let bibNumber: Int?
    let firstName: String?
    let lastName: String?
    let gender: String?
    let age: Int?
    let flexibleGeolocation: String?
    let stopped: Bool?
    let dropped: Bool?
    let finished: Bool?
    let absoluteTimes: [[String?]]?
}
