import Foundation

/// One live-time entry to submit. Field types mirror the old Obj-C `EntryModel`
/// exactly: every attribute is a String (including `withPacer`/`stoppedHere`,
/// which the old app stored as the strings "true"/"false"), so the JSON payload
/// is byte-compatible with what `OSTNetworkManager+Entries` produced.
struct LiveTimeEntry {
    let bibNumber: String
    let splitId: String
    let subSplitKind: String   // EntryModel.bitKey
    let enteredTime: String    // EntryModel.absoluteTime
    let withPacer: String      // "true" / "false"
    let stoppedHere: String    // "true" / "false"
    let source: String

    var attributes: [String: Any] {
        ["bibNumber": bibNumber,
         "splitId": splitId,
         "subSplitKind": subSplitKind,
         "enteredTime": enteredTime,
         "withPacer": withPacer,
         "stoppedHere": stoppedHere,
         "source": source]
    }

    /// `POST events/{id}/import` body, matching the old code's `uniqueKey` + `data`.
    static func eventImportPayload(_ entries: [LiveTimeEntry]) -> [String: Any] {
        // "bitkey" (lowercase k) is intentional — it's the server's uniqueKey field
        // name, distinct from the per-entry "subSplitKind" attribute above. Locked
        // by SubmitPayloadGoldenTests; do not "fix" the casing.
        ["uniqueKey": ["enteredTime", "bitkey", "bibNumber", "source", "withPacer", "stoppedHere"],
         "data": entries.map { ["type": "live_time", "attributes": $0.attributes] }]
    }
}
