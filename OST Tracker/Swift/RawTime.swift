import Foundation

/// One raw time ("read") from the OpenSplitTime `raw_times` JSON:API endpoint.
/// Value type; `parse` is pure so it is unit-testable without the network.
struct RawTime {
    let id: Int
    let bib: String
    let enteredTime: String?
    let absoluteTime: String?
    let subSplitKind: String?   // "in" / "out"
    let source: String?
    let lap: Int?
    let withPacer: Bool
    let stoppedHere: Bool

    /// Parses a decoded JSON:API body (`{ "data": [ { "attributes": { ... } } ] }`).
    /// Rows without a numeric `id` are dropped. Tolerant of missing/null attributes.
    static func parse(_ json: [String: Any]) -> [RawTime] {
        let data = json["data"] as? [[String: Any]] ?? []
        return data.compactMap { row in
            let attrs = row["attributes"] as? [String: Any] ?? [:]
            guard let id = intValue(attrs["id"]) else { return nil }
            return RawTime(
                id: id,
                bib: stringValue(attrs["bibNumber"]) ?? "",
                enteredTime: stringValue(attrs["enteredTime"]),
                absoluteTime: stringValue(attrs["absoluteTime"]),
                subSplitKind: stringValue(attrs["subSplitKind"]),
                source: stringValue(attrs["source"]),
                lap: intValue(attrs["lap"]),
                withPacer: boolValue(attrs["withPacer"]),
                stoppedHere: boolValue(attrs["stoppedHere"])
            )
        }
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if any is NSNull { return nil }
        return nil
    }

    private static func boolValue(_ any: Any?) -> Bool {
        if let b = any as? Bool { return b }
        if let n = any as? NSNumber { return n.boolValue }
        // A stringly-typed "true"/"false" from the API must not silently read as
        // false (the MagicalRecord shim's bool coercion accepts strings too).
        if let s = any as? String { return (s as NSString).boolValue }
        return false
    }
}
