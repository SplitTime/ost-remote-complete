import Foundation

/// Builds the relative path for the live reads poll. Pure → unit-testable.
/// `[` / `]` are left literal; `OSTBackend.getJSONObject` percent-encodes them.
enum LiveReadsRequest {
    static func path(groupId: String, splitName: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+ ")
        let station = splitName.addingPercentEncoding(withAllowedCharacters: allowed) ?? splitName
        return "event_groups/\(groupId)/raw_times?filter[split_name]=\(station)&sort=-id&page[size]=50"
    }
}
