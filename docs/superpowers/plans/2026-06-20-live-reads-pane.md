# Live Reads Pane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only "Live Reads" drawer screen that auto-polls the OpenSplitTime raw_times JSON API every 5s and shows reads landing at the device's current station, newest first, with new rows highlighted.

**Architecture:** Poll `GET /api/v1/event_groups/:id/raw_times?filter[split_name]=<station>&sort=-id&page[size]=50` via the existing `OSTBackend`/`APIClient` (token auth, completion handlers). Pure, unit-tested value types (`RawTime` parser, `LiveReadsMerge` high-water-mark merge, `LiveReadsRequest` path builder) carry all logic; a programmatic `OSTLiveReadsViewController` renders them and owns the timer. No new dependencies, no CoreData, no WebSocket.

**Tech Stack:** Swift + UIKit, iOS 12 deployment target, XCTest. Built from `OST Tracker.xcodeproj` (no CocoaPods/workspace). Module name for `@testable import`: `OST_Remote`.

## Global Constraints

- iOS 12 deployment floor — no `async/await`, no `URLSessionWebSocketTask`, no Combine. Completion handlers only.
- Zero third-party dependencies. No CocoaPods, no SPM additions.
- Build/test command: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test` (substitute any available sim from `xcrun simctl list devices available`; use `build` instead of `test` for build-only checks).
- New Swift source files must be added to the **OST Remote** app target; new test files to the **OST TrackerTests** target (edit `OST Tracker.xcodeproj/project.pbxproj` or add via Xcode). JSON fixtures under `Verification/fixtures/` are picked up automatically (folder reference) — no pbxproj edit needed.
- Module under test imports as `@testable import OST_Remote`.
- Reads scope: this station only (`CurrentCourse.splitName`), all sources. Time display: `entered_time`, fall back to a formatted `absolute_time`.
- Do NOT touch the existing `"-1"` sentinel filtering or other screens.

---

### Task 1: `RawTime` value type + JSON:API parser

**Files:**
- Create: `OST Tracker/Swift/RawTime.swift`
- Create: `Verification/fixtures/raw_times_437.json`
- Test: `OST TrackerTests/Swift/RawTimeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct RawTime { let id: Int; let bib: String; let enteredTime: String?; let absoluteTime: String?; let subSplitKind: String?; let source: String?; let lap: Int?; let withPacer: Bool; let stoppedHere: Bool }`
  - `static func RawTime.parse(_ json: [String: Any]) -> [RawTime]`

- [ ] **Step 1: Create the fixture** `Verification/fixtures/raw_times_437.json`

```json
{
  "data": [
    {
      "id": "1001",
      "type": "raw_times",
      "attributes": {
        "id": 1001,
        "eventGroupId": 437,
        "source": "ost-timing-system",
        "absoluteTime": "2026-06-20T15:42:03.000Z",
        "enteredTime": "10:42:03",
        "bibNumber": "57",
        "lap": 1,
        "splitName": "Aid Station 1",
        "subSplitKind": "in",
        "dataStatus": "good",
        "stoppedHere": false,
        "withPacer": false,
        "remarks": null
      }
    },
    {
      "id": "1002",
      "type": "raw_times",
      "attributes": {
        "id": 1002,
        "eventGroupId": 437,
        "source": "ost-remote",
        "absoluteTime": "2026-06-20T15:43:10.000Z",
        "enteredTime": null,
        "bibNumber": "58",
        "lap": 2,
        "splitName": "Aid Station 1",
        "subSplitKind": "out",
        "dataStatus": null,
        "stoppedHere": true,
        "withPacer": true,
        "remarks": "dropped"
      }
    }
  ]
}
```

Note the JSON:API `attributes` use lowerCamelCase keys — this matches the app's other API responses (see `event_group_437.json`). The parser reads `id` from `attributes.id` (an Int), not the string top-level `id`.

- [ ] **Step 2: Write the failing test** `OST TrackerTests/Swift/RawTimeTests.swift`

```swift
import XCTest
@testable import OST_Remote

final class RawTimeTests: XCTestCase {

    private func loadFixture() -> [String: Any] {
        let data = Fixture.data("raw_times_437")
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    func test_parse_returnsAllRows() {
        let rows = RawTime.parse(loadFixture())
        XCTAssertEqual(rows.count, 2)
    }

    func test_parse_mapsCoreFields() {
        let rows = RawTime.parse(loadFixture())
        let first = rows[0]
        XCTAssertEqual(first.id, 1001)
        XCTAssertEqual(first.bib, "57")
        XCTAssertEqual(first.enteredTime, "10:42:03")
        XCTAssertEqual(first.subSplitKind, "in")
        XCTAssertEqual(first.source, "ost-timing-system")
        XCTAssertEqual(first.lap, 1)
        XCTAssertFalse(first.withPacer)
        XCTAssertFalse(first.stoppedHere)
    }

    func test_parse_handlesNullsAndFlags() {
        let rows = RawTime.parse(loadFixture())
        let second = rows[1]
        XCTAssertNil(second.enteredTime)
        XCTAssertEqual(second.absoluteTime, "2026-06-20T15:43:10.000Z")
        XCTAssertTrue(second.withPacer)
        XCTAssertTrue(second.stoppedHere)
    }

    func test_parse_skipsRowsMissingId() {
        let json: [String: Any] = ["data": [["type": "raw_times", "attributes": ["bibNumber": "99"]]]]
        XCTAssertTrue(RawTime.parse(json).isEmpty)
    }

    func test_parse_emptyDataReturnsEmpty() {
        XCTAssertTrue(RawTime.parse(["data": []]).isEmpty)
        XCTAssertTrue(RawTime.parse([:]).isEmpty)
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — `RawTime` is undefined / does not compile.

- [ ] **Step 4: Write the implementation** `OST Tracker/Swift/RawTime.swift`

```swift
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
        return false
    }
}
```

- [ ] **Step 5: Add files to targets**

Add `RawTime.swift` to the **OST Remote** app target and `RawTimeTests.swift` to the **OST TrackerTests** target (Xcode group drag, or add `PBXBuildFile`/`PBXFileReference` entries to `OST Tracker.xcodeproj/project.pbxproj`). The fixture needs no pbxproj edit (folder reference).

- [ ] **Step 6: Run the test to verify it passes**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS — all `RawTimeTests` green.

- [ ] **Step 7: Commit**

```bash
git add "OST Tracker/Swift/RawTime.swift" "OST TrackerTests/Swift/RawTimeTests.swift" "Verification/fixtures/raw_times_437.json" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: RawTime JSON:API parser for live reads"
```

---

### Task 2: `LiveReadsMerge` high-water-mark merge

**Files:**
- Create: `OST Tracker/Swift/LiveReadsMerge.swift`
- Test: `OST TrackerTests/Swift/LiveReadsMergeTests.swift`

**Interfaces:**
- Consumes: `RawTime` (Task 1).
- Produces:
  - `enum LiveReadsMerge`
  - `static func merge(existing: [RawTime], incoming: [RawTime], highWaterMark: Int) -> (rows: [RawTime], newIds: [Int], highWaterMark: Int)`
  - Contract: result `rows` are all unique reads sorted by descending `id` (newest first); `newIds` are ids in `incoming` strictly greater than the input `highWaterMark` and not already in `existing`; result `highWaterMark` is the max id across all rows (or the input hwm if no rows).

- [ ] **Step 1: Write the failing test** `OST TrackerTests/Swift/LiveReadsMergeTests.swift`

```swift
import XCTest
@testable import OST_Remote

final class LiveReadsMergeTests: XCTestCase {

    private func read(_ id: Int) -> RawTime {
        RawTime(id: id, bib: "\(id)", enteredTime: nil, absoluteTime: nil,
                subSplitKind: "in", source: "t", lap: 1, withPacer: false, stoppedHere: false)
    }

    func test_firstLoad_fromZeroHwm_noNewHighlights() {
        let result = LiveReadsMerge.merge(existing: [], incoming: [read(3), read(2), read(1)], highWaterMark: 0)
        XCTAssertEqual(result.rows.map { $0.id }, [3, 2, 1])
        XCTAssertEqual(result.newIds, [3, 2, 1])   // all above hwm 0
        XCTAssertEqual(result.highWaterMark, 3)
    }

    func test_subsequentPoll_detectsOnlyNewIds() {
        let existing = [read(3), read(2), read(1)]
        let incoming = [read(5), read(4), read(3)]   // 3 overlaps, 4 & 5 new
        let result = LiveReadsMerge.merge(existing: existing, incoming: incoming, highWaterMark: 3)
        XCTAssertEqual(result.rows.map { $0.id }, [5, 4, 3, 2, 1])
        XCTAssertEqual(result.newIds.sorted(), [4, 5])
        XCTAssertEqual(result.highWaterMark, 5)
    }

    func test_noNewRows_isStable() {
        let existing = [read(2), read(1)]
        let result = LiveReadsMerge.merge(existing: existing, incoming: [read(2), read(1)], highWaterMark: 2)
        XCTAssertEqual(result.rows.map { $0.id }, [2, 1])
        XCTAssertTrue(result.newIds.isEmpty)
        XCTAssertEqual(result.highWaterMark, 2)
    }

    func test_emptyIncoming_keepsExisting() {
        let existing = [read(2), read(1)]
        let result = LiveReadsMerge.merge(existing: existing, incoming: [], highWaterMark: 2)
        XCTAssertEqual(result.rows.map { $0.id }, [2, 1])
        XCTAssertTrue(result.newIds.isEmpty)
        XCTAssertEqual(result.highWaterMark, 2)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — `LiveReadsMerge` is undefined.

- [ ] **Step 3: Write the implementation** `OST Tracker/Swift/LiveReadsMerge.swift`

```swift
import Foundation

/// Pure merge for the live reads list (Approach A): fold a freshly fetched page
/// into the running list, de-duplicating by `id`, keeping newest-first order, and
/// reporting which ids are genuinely new (for highlight) via a high-water-mark.
enum LiveReadsMerge {
    static func merge(existing: [RawTime],
                      incoming: [RawTime],
                      highWaterMark: Int) -> (rows: [RawTime], newIds: [Int], highWaterMark: Int) {
        let existingIds = Set(existing.map { $0.id })

        let newIds = incoming
            .filter { $0.id > highWaterMark && !existingIds.contains($0.id) }
            .map { $0.id }

        var byId = [Int: RawTime]()
        for row in existing { byId[row.id] = row }
        for row in incoming { byId[row.id] = row }

        let rows = byId.values.sorted { $0.id > $1.id }
        let newHwm = rows.first.map { max($0.id, highWaterMark) } ?? highWaterMark

        return (rows, newIds, newHwm)
    }
}
```

- [ ] **Step 4: Add the test file to the OST TrackerTests target and the source file to the OST Remote target** (pbxproj/Xcode, as in Task 1 Step 5).

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS — all `LiveReadsMergeTests` green.

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/Swift/LiveReadsMerge.swift" "OST TrackerTests/Swift/LiveReadsMergeTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: LiveReadsMerge high-water-mark merge"
```

---

### Task 3: Request path builder + `OSTBackend.fetchRawTimes`

**Files:**
- Create: `OST Tracker/Swift/LiveReadsRequest.swift`
- Modify: `OST Tracker/Swift/OSTBackend.swift` (add a method near `fetchNotExpected`, ~line 40)
- Test: `OST TrackerTests/Swift/LiveReadsRequestTests.swift`

**Interfaces:**
- Consumes: `RawTime.parse` (Task 1), `OSTBackend.request` (existing private helper that calls `getJSONObject`).
- Produces:
  - `enum LiveReadsRequest`
  - `static func LiveReadsRequest.path(groupId: String, splitName: String) -> String`
  - `@objc func OSTBackend.fetchRawTimes(groupId: String, splitName: String, completion: @escaping (Any?, Error?) -> Void)`

- [ ] **Step 1: Write the failing test** `OST TrackerTests/Swift/LiveReadsRequestTests.swift`

```swift
import XCTest
@testable import OST_Remote

final class LiveReadsRequestTests: XCTestCase {

    func test_path_includesGroupStationSortAndPageSize() {
        let path = LiveReadsRequest.path(groupId: "437", splitName: "Aid Station 1")
        XCTAssertTrue(path.hasPrefix("event_groups/437/raw_times?"))
        XCTAssertTrue(path.contains("filter[split_name]=Aid%20Station%201"), path)
        XCTAssertTrue(path.contains("sort=-id"), path)
        XCTAssertTrue(path.contains("page[size]=50"), path)
    }

    func test_path_encodesAmpersandsInStationName() {
        let path = LiveReadsRequest.path(groupId: "5", splitName: "Start & Finish")
        XCTAssertTrue(path.contains("Start%20%26%20Finish"), path)
    }
}
```

Note: the `[`/`]` in `filter[split_name]`/`page[size]` are left literal here — `OSTBackend.getJSONObject` percent-encodes them before building the URL (see its implementation). Only the **value** is percent-encoded by the builder.

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — `LiveReadsRequest` is undefined.

- [ ] **Step 3: Write the path builder** `OST Tracker/Swift/LiveReadsRequest.swift`

```swift
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS — `LiveReadsRequestTests` green.

(Add `LiveReadsRequest.swift` to the OST Remote target and the test to OST TrackerTests before running, per Task 1 Step 5.)

- [ ] **Step 5: Add the `fetchRawTimes` method to `OSTBackend.swift`**

Insert directly after the `fetchNotExpected(...)` method (around line 44):

```swift
    /// Polls the raw_times JSON:API for the given event group + station, newest
    /// first, capped at the server max page size. Returns the parsed JSON dict
    /// (callers run it through `RawTime.parse`). Mirrors `fetchNotExpected`.
    @objc func fetchRawTimes(groupId: String,
                             splitName: String,
                             completion: @escaping (Any?, Error?) -> Void) {
        request(LiveReadsRequest.path(groupId: groupId, splitName: splitName), completion: completion)
    }
```

- [ ] **Step 6: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add "OST Tracker/Swift/LiveReadsRequest.swift" "OST TrackerTests/Swift/LiveReadsRequestTests.swift" "OST Tracker/Swift/OSTBackend.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: OSTBackend.fetchRawTimes + live reads request path"
```

---

### Task 4: `OSTLiveReadsViewController` (programmatic screen)

**Files:**
- Create: `OST Tracker/ViewControllers/OSTLiveReadsViewController.swift`
- Test: none (UI / timer — human-verified in simulator).

**Interfaces:**
- Consumes: `OSTBackend.shared.fetchRawTimes` (Task 3), `RawTime.parse` (Task 1), `LiveReadsMerge.merge` (Task 2), `CurrentCourse.eventGroupId()` / `CurrentCourse.splitName()` (existing Obj-C class methods), `AppDelegate.getInstance().showTracker` (existing), `OSTBaseViewController` (existing base).

**Design note:** Built programmatically (no storyboard) to stay self-contained and avoid storyboard/pbxproj asset friction. This is a deliberate, simpler deviation from the spec's "LiveReads.storyboard"; the drawer only needs a `UIViewController`.

- [ ] **Step 1: Create the view controller** `OST Tracker/ViewControllers/OSTLiveReadsViewController.swift`

```swift
import UIKit

/// Read-only live monitor of raw times ("reads") at the device's current
/// station. Auto-polls every 5s while visible; pauses off-screen / backgrounded.
/// New reads are highlighted briefly. Header Refresh button + Go-to-Live-Entry.
final class OSTLiveReadsViewController: OSTBaseViewController, UITableViewDataSource {

    private let pollInterval: TimeInterval = 5
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()
    private let updatedLabel = UILabel()
    private let liveDot = UIView()

    private var rows: [RawTime] = []
    private var highWaterMark = 0
    private var newIds: Set<Int> = []
    private var timer: Timer?

    private var groupId: String { CurrentCourse.eventGroupId() ?? "" }
    private var stationName: String { CurrentCourse.splitName() ?? "" }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(stopPolling),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startPolling),
            name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        titleLabel.text = "Live Reads — \(stationName)"
        rows = []; highWaterMark = 0; newIds = []
        tableView.reloadData()
        guard !groupId.isEmpty, !stationName.isEmpty else { updatedLabel.text = "No station selected"; return }
        fetch(showSpinner: true)
        startPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPolling()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Polling

    @objc private func startPolling() {
        stopPolling()
        guard view.window != nil, !groupId.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetch(showSpinner: false)
        }
    }

    @objc private func stopPolling() { timer?.invalidate(); timer = nil }

    @objc private func onRefresh() { fetch(showSpinner: false); startPolling() }

    @objc private func onGoToLiveEntry() { AppDelegate.getInstance().showTracker() }

    private func fetch(showSpinner: Bool) {
        guard !groupId.isEmpty, !stationName.isEmpty else { return }
        if showSpinner { ostShowBlockingSpinner() }
        OSTBackend.shared.fetchRawTimes(groupId: groupId, splitName: stationName) { [weak self] object, error in
            guard let self = self else { return }
            if showSpinner { self.ostHideBlockingSpinner() }
            guard error == nil, let dict = object as? [String: Any] else {
                self.liveDot.backgroundColor = .lightGray
                self.updatedLabel.text = "Couldn't refresh"
                return
            }
            let incoming = RawTime.parse(dict)
            let result = LiveReadsMerge.merge(existing: self.rows, incoming: incoming, highWaterMark: self.highWaterMark)
            self.rows = result.rows
            self.highWaterMark = result.highWaterMark
            self.newIds = Set(result.newIds)
            self.liveDot.backgroundColor = UIColor.systemGreen
            self.updatedLabel.text = "Updated " + Self.clock.string(from: Date())
            self.tableView.reloadData()
        }
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.isEmpty ? 0 : rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "read") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "read")
        let r = rows[indexPath.row]
        let kind = (r.subSplitKind ?? "").uppercased()
        let time = r.enteredTime ?? Self.shortTime(from: r.absoluteTime) ?? "—"
        cell.textLabel?.text = "#\(r.bib)   \(time)" + (kind.isEmpty ? "" : "   [\(kind)]")
        var flags: [String] = []
        if let lap = r.lap, lap > 1 { flags.append("L\(lap)") }
        if r.withPacer { flags.append("pacer") }
        if r.stoppedHere { flags.append("stopped") }
        let source = r.source ?? ""
        cell.detailTextLabel?.text = [source, flags.joined(separator: " · ")].filter { !$0.isEmpty }.joined(separator: "   ")
        cell.contentView.backgroundColor = newIds.contains(r.id) ? UIColor.systemYellow.withAlphaComponent(0.35) : .clear
        if newIds.contains(r.id) {
            UIView.animate(withDuration: 1.5) { cell.contentView.backgroundColor = .clear }
        }
        return cell
    }

    // MARK: - UI construction

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    private static func shortTime(from iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let inF = ISO8601DateFormatter()
        inF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = inF.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
        return clock.string(from: d)
    }

    private func buildUI() {
        let header = UIView(); header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = UIColor(white: 0.97, alpha: 1)
        titleLabel.font = .boldSystemFont(ofSize: 18)
        liveDot.layer.cornerRadius = 5
        liveDot.backgroundColor = .lightGray
        liveDot.translatesAutoresizingMaskIntoConstraints = false
        updatedLabel.font = .systemFont(ofSize: 12); updatedLabel.textColor = .gray

        let refresh = UIButton(type: .system)
        refresh.setTitle("⟳ Refresh", for: .normal)
        refresh.addTarget(self, action: #selector(onRefresh), for: .touchUpInside)

        let goLive = UIButton(type: .system)
        goLive.setTitle("Go to Live Entry", for: .normal)
        goLive.titleLabel?.font = .boldSystemFont(ofSize: 16)
        goLive.backgroundColor = UIColor.systemBlue
        goLive.setTitleColor(.white, for: .normal)
        goLive.layer.cornerRadius = 8
        goLive.translatesAutoresizingMaskIntoConstraints = false
        goLive.addTarget(self, action: #selector(onGoToLiveEntry), for: .touchUpInside)

        let statusStack = UIStackView(arrangedSubviews: [liveDot, updatedLabel])
        statusStack.alignment = .center; statusStack.spacing = 6
        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), statusStack, refresh])
        headerStack.alignment = .center; headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)

        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = 56

        view.addSubview(header); view.addSubview(tableView); view.addSubview(goLive)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            liveDot.widthAnchor.constraint(equalToConstant: 10),
            liveDot.heightAnchor.constraint(equalToConstant: 10),

            header.topAnchor.constraint(equalTo: guide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 56),
            headerStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: goLive.topAnchor, constant: -8),

            goLive.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            goLive.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            goLive.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
            goLive.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
}
```

If `CurrentCourse.eventGroupId()` / `CurrentCourse.splitName()` are not visible from Swift, confirm they are declared in `OST Tracker-Bridging-Header.h` (the class is already imported there — see grep of `CurrentCourse`). If `AppDelegate.getInstance()`/`showTracker` are not exposed, they are already used from Obj-C (`OSTRightMenuViewController.m onSubmit:`) and declared in the bridging header.

- [ ] **Step 2: Add the file to the OST Remote target** (pbxproj/Xcode, per Task 1 Step 5).

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED. Resolve any bridging-header gaps for `CurrentCourse` / `AppDelegate` as noted.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTLiveReadsViewController.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: OSTLiveReadsViewController live reads screen"
```

---

### Task 5: Wire "Live Reads" into the right-side drawer menu

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTRightMenuViewController.m` (add an action like `onCrossCheck:`, ~line 151)
- Modify: the right-menu storyboard/xib that hosts the menu buttons (add a "Live Reads" button wired to the new action). Locate it by the existing `onCrossCheck:`/`onUtilities:` button connections.
- Test: none (UI navigation — human-verified).

**Interfaces:**
- Consumes: `OSTLiveReadsViewController` (Task 4), `AppDelegate.getInstance().rightMenuVC` (existing drawer container).

- [ ] **Step 1: Add the action to `OSTRightMenuViewController.m`**

Insert after `onCrossCheck:` (around line 158). The Swift class is exposed to Obj-C via the generated header (`#import "OST_Remote-Swift.h"` is already present for `OSTRunnerTrackerViewController` — reuse it):

```objc
- (IBAction)onLiveReads:(id)sender
{
    OSTLiveReadsViewController *controller = [[OSTLiveReadsViewController alloc] init];
    [AppDelegate getInstance].rightMenuVC.centerViewController = controller;
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}
```

If the generated-header import is not already at the top of this file, add `#import "OST_Remote-Swift.h"` (match the exact product-module header name used elsewhere in the project, e.g. by `OSTRunnerTrackerViewController` references).

- [ ] **Step 2: Add a "Live Reads" button in the menu storyboard/xib**

In the storyboard/xib that defines the right menu (the one with the "Cross Check"/"Utilities" buttons), duplicate the Cross Check button, relabel it "Live Reads", and connect its Touch Up Inside to the File's Owner `onLiveReads:` action. Place it adjacent to Cross Check (respect the existing `tag`-based sort order seen in `sortedSubmenuViews`).

- [ ] **Step 3: Build**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTRightMenuViewController.m" "OST Tracker.xcodeproj/project.pbxproj"
# include the modified storyboard/xib path reported by `git status`
git commit -m "feat: add Live Reads item to right-side drawer menu"
```

- [ ] **Step 5: Human verification in simulator**

Hand off to the user (per batch-then-human-verify norm). Verify, logged in to event 437 at a station with reads:
1. Open the drawer → tap **Live Reads** → screen shows reads for the current station, newest on top.
2. Submit a read for that station (timing system or another device) → within ~5s it appears at the top, highlighted, fading to normal.
3. Tap **⟳ Refresh** → list refreshes immediately; no duplicate rows.
4. Leave the screen / background the app → polling stops (no network activity); return → it resumes and re-fetches.
5. Tap **Go to Live Entry** → lands on the Runner Tracker entry screen.
6. Confirm it works on a **Volunteer-level** account (no admin), and shows "No reads yet" cleanly at an empty station.

---

## Self-Review

**Spec coverage:**
- Drawer screen placement → Task 5 ✓
- This-station/all-sources scope → Task 3 path (`filter[split_name]`, no source filter) ✓
- 5s auto-poll, pause off-screen/background → Task 4 timer + notifications ✓
- Row content (bib+time+in/out, source, lap/pacer/stopped) → Task 4 cell ✓
- Read-only + Go-to-Live-Entry + visible Refresh → Task 4 buttons ✓
- Approach A high-water-mark merge → Task 2 ✓
- page[size]=50, entered_time w/ absolute fallback → Task 3 path, Task 4 cell ✓
- Volunteer access, non-blocking errors, empty state → Task 4 + Task 5 Step 5 ✓
- TDD on pure pieces (parse, merge, path) → Tasks 1–3 ✓; UI human-verified → Task 5 ✓
- Out-of-scope items (CoreData, push, multi-source, tap-to-act) → not built ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete.

**Type consistency:** `RawTime` fields/`parse` signature consistent across Tasks 1, 2, 4. `LiveReadsMerge.merge` tuple labels (`rows`/`newIds`/`highWaterMark`) consistent in Tasks 2 and 4. `LiveReadsRequest.path` / `OSTBackend.fetchRawTimes` signatures consistent in Tasks 3 and 4.

**Known follow-ups (acceptable):** time-formatting uses `ISO8601DateFormatter` (iOS 11+, fine on the iOS 12 floor); storyboard/pbxproj edits are manual and verified by build + human pass.
