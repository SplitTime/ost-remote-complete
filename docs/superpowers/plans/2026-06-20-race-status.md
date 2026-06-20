# Race Status Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only "Race Status" screen that fetches an event's spread and shows, on one page, a single runner's times through the course or one aid station's progress through the whole field.

**Architecture:** A programmatic, Theme-styled `OSTRaceStatusViewController` (subclass of `OSTBaseViewController`, mirroring `OSTLiveReadsViewController`) reached from a new drawer-menu button. Networking adds two read methods to `OSTBackend` that decode the spread / event-group through `APIClient`'s existing `get<T: Decodable>` path. All parsing and presentation logic lives in pure, unit-tested Swift (`SpreadModels.swift`, `RaceStatusViewModel.swift`); the view controller only renders the resulting value types.

**Tech Stack:** Swift (iOS 12 compatible — completion handlers, no async/await), UIKit, XCTest. The design system (`Theme`, `SelectableOptionList`, `BottomSheetPicker`, `PrimaryButton`). New files are registered in `OST Tracker.xcodeproj` via the `xcodeproj` Ruby gem (1.27.0, already installed).

## Global Constraints

- iOS 12 floor — no `async`/`await`, no `UISheetPresentationController`, no APIs newer than iOS 12 except behind `if #available`. Match the existing code's completion-handler style.
- Never hardcode colors/fonts — use `Theme` roles and `Theme.Font`/`Theme.Metric` only.
- New `.swift` files in the app target must be added to BOTH application targets: `OST Remote` and `OST Remote Dev`. New test files go to `OST TrackerTests`.
- The fixture folder `Verification/fixtures/` is a folder reference already in the test bundle — JSON added there needs NO project change. The fixture `Verification/fixtures/spread-test-lonesome-100.json` is already committed.
- Build/verify on simulator `iPad (9th generation)`.
- Commit after every green step. End commit messages with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- DRY: reuse `JSONAPIDoc`/`JSONAPIResource` (in `APIModels.swift`), `APIClient.get`, `ConnectivityChecker`, and the design-system components rather than re-implementing.

### Reference commands

Build:
```bash
xcodebuild build -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad (9th generation)' -quiet
```

Run one test class:
```bash
xcodebuild test -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad (9th generation)' \
  -only-testing:'OST TrackerTests/RaceStatusTests' 2>&1 | tail -40
```
(If `-only-testing` reports the identifier is unknown, run the whole suite without
`-only-testing` and grep the output for `RaceStatusTests`.)

### Spread response shape (reference)

`GET events/{slug}/spread` returns:
- `data.attributes`: `name`, `courseName`, `organizationName`, `displayStyle`,
  `eventStartTime` (ISO8601 with offset, e.g. `2022-07-22T06:00:00.000-06:00`),
  `splitHeaderData`: `[{ title, split_name, distance, extensions: []|["In","Out"], lap }]`.
- `included`: array of `{ type: "effortTimesRows", attributes: { overallRank,
  genderRank, bibNumber, firstName, lastName, gender, age, flexibleGeolocation,
  stopped, dropped, finished, absoluteTimes } }`. `absoluteTimes` is aligned by
  index to `splitHeaderData`; each element is an array of ISO strings or `null`
  (1 entry for a no-extension station, 2 for an In/Out station).

The committed fixture has **18 split headers** and **151 effortTimesRows**.

---

### Task 0: File-registration helper script

**Files:**
- Create: `scripts/add_file_to_targets.rb`

**Interfaces:**
- Produces: a CLI `ruby scripts/add_file_to_targets.rb <path> <target> [<target>...]`
  that idempotently adds a file reference to the project and to each named
  target's source build phase, then saves. Used by later tasks to register new
  `.swift` files.

- [ ] **Step 1: Write the script**

```ruby
#!/usr/bin/env ruby
# Adds a source file to the OST Tracker project and to the named targets'
# compile phase. Idempotent: safe to run again.
require 'xcodeproj'

path = ARGV[0]
target_names = ARGV[1..-1]
abort "usage: add_file_to_targets.rb <path> <target>..." if path.nil? || target_names.empty?

project_path = 'OST Tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
abs = File.expand_path(path)

changed = false
ref = project.files.find { |f| f.real_path.to_s == abs }
if ref.nil?
  ref = project.main_group.new_file(path)
  changed = true
end

target_names.each do |name|
  target = project.targets.find { |t| t.name == name }
  abort "no target named #{name}" if target.nil?
  already = target.source_build_phase.files_references.include?(ref)
  unless already
    target.add_file_references([ref])
    changed = true
  end
  puts "#{already ? 'already in' : 'added to'} #{name}: #{path}"
end

# Only write when something actually changed — keeps the diff minimal and the
# script idempotent (Xcodeproj#save rewrites the whole file otherwise).
project.save if changed
```

- [ ] **Step 2: Verify it runs (no-op on an existing file)**

Run:
```bash
ruby scripts/add_file_to_targets.rb "OST Tracker/Swift/OSTBackend.swift" "OST Remote" "OST Remote Dev"
```
Expected: prints `already in OST Remote: ...` and `already in OST Remote Dev: ...`, exits 0. `git status` shows `project.pbxproj` UNCHANGED (idempotent).

- [ ] **Step 3: Commit**

```bash
git add scripts/add_file_to_targets.rb
git commit -m "build: add xcodeproj file-registration helper script

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 1: Spread models + envelope parsing

**Files:**
- Create: `OST Tracker/Swift/SpreadModels.swift`
- Create (test): `OST TrackerTests/Swift/RaceStatusTests.swift`

**Interfaces:**
- Produces:
  - `struct EventSpread` with `name, courseName, displayStyle: String`,
    `eventStartTime: Date`, `eventTimeZone: TimeZone`,
    `splitHeaders: [SplitHeader]`, `efforts: [EffortRow]`, and
    `static func decode(from data: Data) throws -> EventSpread`. `EventSpread` is `Decodable`.
  - `struct SplitHeader` — `title, splitName: String`, `distanceMeters: Double`,
    `extensions: [String]`, `lap: Int`, computed `var hasInOut: Bool`,
    plus a memberwise `init(title:splitName:distanceMeters:extensions:lap:)`.
  - `struct EffortRow` — `overallRank, genderRank, bibNumber: Int`,
    `firstName, lastName, gender: String`, `age: Int?`,
    `flexibleGeolocation: String?`, `stopped, dropped, finished: Bool`,
    `absoluteTimes: [[Date?]]`, computed `var fullName: String`, plus a memberwise
    `init(overallRank:genderRank:bibNumber:firstName:lastName:gender:age:flexibleGeolocation:stopped:dropped:finished:absoluteTimes:)`.
  - `struct EventRef { let slug: String; let name: String }`.

- [ ] **Step 1: Write the failing test**

Create `OST TrackerTests/Swift/RaceStatusTests.swift`:
```swift
import XCTest
@testable import OST_Remote

final class RaceStatusTests: XCTestCase {

    private func loadSpread() throws -> EventSpread {
        try EventSpread.decode(from: Fixture.data("spread-test-lonesome-100"))
    }

    // MARK: - Parsing

    func test_parsesSpreadEnvelope() throws {
        let spread = try loadSpread()
        XCTAssertEqual(spread.name, "Test Lonesome 100")
        XCTAssertEqual(spread.splitHeaders.count, 18)
        XCTAssertEqual(spread.efforts.count, 151)
    }

    func test_splitHeaderExtensions() throws {
        let spread = try loadSpread()
        XCTAssertEqual(spread.splitHeaders[0].title, "Start")
        XCTAssertFalse(spread.splitHeaders[0].hasInOut)
        XCTAssertEqual(spread.splitHeaders[1].title, "Raspberry 1")
        XCTAssertEqual(spread.splitHeaders[1].extensions, ["In", "Out"])
        XCTAssertTrue(spread.splitHeaders[1].hasInOut)
    }

    func test_eventTimeZoneFromOffset() throws {
        let spread = try loadSpread()
        XCTAssertEqual(spread.eventTimeZone.secondsFromGMT(), -6 * 3600)
    }

    func test_effortRowParsesTimesAlignedToHeaders() throws {
        let spread = try loadSpread()
        let beer = try XCTUnwrap(spread.efforts.first { $0.bibNumber == 28 })
        XCTAssertEqual(beer.fullName, "Raul Beer")
        XCTAssertEqual(beer.overallRank, 1)
        XCTAssertTrue(beer.finished)
        // absoluteTimes aligned to the 18 headers; Raspberry 1 (idx 1) is In/Out.
        XCTAssertEqual(beer.absoluteTimes.count, 18)
        XCTAssertEqual(beer.absoluteTimes[1].count, 2)
        XCTAssertNotNil(beer.absoluteTimes[1][0]) // In time present
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the test-class command above. Expected: FAIL — `EventSpread` / `EffortRow` undefined (won't compile).

- [ ] **Step 3: Write `SpreadModels.swift`**

```swift
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
              let hours = Int(tail.prefix(3)), let minutes = Int(tail.suffix(2)) else {
            return .current
        }
        let sign = hours < 0 ? -1 : 1
        return TimeZone(secondsFromGMT: hours * 3600 + sign * minutes * 60) ?? .current
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
```

- [ ] **Step 4: Register both new files**

```bash
ruby scripts/add_file_to_targets.rb "OST Tracker/Swift/SpreadModels.swift" "OST Remote" "OST Remote Dev"
ruby scripts/add_file_to_targets.rb "OST TrackerTests/Swift/RaceStatusTests.swift" "OST TrackerTests"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the test-class command. Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: spread response models + envelope parsing

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Time formatting helpers

**Files:**
- Create: `OST Tracker/Swift/RaceStatusViewModel.swift`
- Modify (test): `OST TrackerTests/Swift/RaceStatusTests.swift`

**Interfaces:**
- Consumes: `EventSpread`, `EffortRow`, `SplitHeader` (Task 1).
- Produces `enum RaceStatusFormat`:
  - `static func elapsed(from start: Date, to t: Date) -> String` — `"H:MM"`, hours
    unbounded (e.g. `"24:20"`); negative interval → `"—"`.
  - `static func timeOfDay(_ t: Date, in tz: TimeZone) -> String` — `"HH:mm"` in `tz`.
  - `static func dayOffset(from start: Date, to t: Date, in tz: TimeZone) -> Int` —
    whole-day difference between the two calendar days in `tz`.

- [ ] **Step 1: Write the failing tests**

Append to `RaceStatusTests.swift`:
```swift
extension RaceStatusTests {
    private func mtZone() -> TimeZone { TimeZone(secondsFromGMT: -6 * 3600)! }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tz: TimeZone) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.date(from: c)!
    }

    func test_elapsedFormatsHoursAndMinutes() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 6, 0, tz: tz)
        let t = date(2022, 7, 22, 9, 13, tz: tz)
        XCTAssertEqual(RaceStatusFormat.elapsed(from: start, to: t), "3:13")
    }

    func test_elapsedExceeds24Hours() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 6, 0, tz: tz)
        let t = date(2022, 7, 23, 6, 20, tz: tz)
        XCTAssertEqual(RaceStatusFormat.elapsed(from: start, to: t), "24:20")
    }

    func test_timeOfDayInEventZone() {
        let tz = mtZone()
        let t = date(2022, 7, 22, 9, 13, tz: tz)
        XCTAssertEqual(RaceStatusFormat.timeOfDay(t, in: tz), "09:13")
    }

    func test_dayOffsetCrossesMidnight() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 6, 0, tz: tz)
        let sameDay = date(2022, 7, 22, 23, 0, tz: tz)
        let nextDay = date(2022, 7, 23, 2, 0, tz: tz)
        XCTAssertEqual(RaceStatusFormat.dayOffset(from: start, to: sameDay, in: tz), 0)
        XCTAssertEqual(RaceStatusFormat.dayOffset(from: start, to: nextDay, in: tz), 1)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run the test-class command. Expected: FAIL — `RaceStatusFormat` undefined.

- [ ] **Step 3: Create `RaceStatusViewModel.swift` with the formatter**

```swift
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
```

- [ ] **Step 4: Register the new file**

```bash
ruby scripts/add_file_to_targets.rb "OST Tracker/Swift/RaceStatusViewModel.swift" "OST Remote" "OST Remote Dev"
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the test-class command. Expected: PASS (now 8 tests).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: race-status time formatting helpers

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Effort status derivation

**Files:**
- Modify: `OST Tracker/Swift/RaceStatusViewModel.swift`
- Modify (test): `OST TrackerTests/Swift/RaceStatusTests.swift`

**Interfaces:**
- Consumes: `EffortRow`, `SplitHeader` (Task 1).
- Produces:
  - `enum EffortStatus: Equatable { case through(arrival: Date); case expected; case dropped(atStation: String); case notStarted }`
  - `func furthestSplitIndex(_ e: EffortRow) -> Int` — highest index with any
    non-nil sub-split time, or `-1`.
  - `func effortStatus(_ e: EffortRow, atSplit idx: Int, headers: [SplitHeader]) -> EffortStatus`.

Status rules (for the aid-station view): a runner with a time at `idx` is
`.through` (arrival = first non-nil sub-split = the In time). Otherwise: if
`dropped`, `.dropped(atStation:)` titled by their furthest reached split; else if
they have any earlier time, `.expected`; else `.notStarted`.

- [ ] **Step 1: Write the failing tests**

Append to `RaceStatusTests.swift`:
```swift
extension RaceStatusTests {
    private func headers(_ n: Int) -> [SplitHeader] {
        (0..<n).map { SplitHeader(title: "S\($0)", splitName: "S\($0)",
                                  distanceMeters: Double($0) * 1000, extensions: ["In", "Out"], lap: 1) }
    }
    private func effort(bib: Int, times: [[Date?]], dropped: Bool = false, finished: Bool = false) -> EffortRow {
        EffortRow(overallRank: bib, genderRank: bib, bibNumber: bib, firstName: "F\(bib)",
                  lastName: "L\(bib)", dropped: dropped, finished: finished, absoluteTimes: times)
    }

    func test_furthestSplitIndex() {
        let t = Date()
        let e = effort(bib: 1, times: [[t, t], [t, nil], [nil, nil]])
        XCTAssertEqual(furthestSplitIndex(e), 1)
        let none = effort(bib: 2, times: [[nil, nil], [nil, nil]])
        XCTAssertEqual(furthestSplitIndex(none), -1)
    }

    func test_status_through_expected_dropped_notStarted() {
        let h = headers(4)
        let t = Date()
        // Through idx 2 (has an In time there)
        let through = effort(bib: 1, times: [[t, t], [t, t], [t, nil], [nil, nil]])
        XCTAssertEqual(effortStatus(through, atSplit: 2, headers: h), .through(arrival: t))
        // Expected at idx 2: cleared idx 1, no time at idx 2, not dropped
        let expected = effort(bib: 2, times: [[t, t], [t, t], [nil, nil], [nil, nil]])
        XCTAssertEqual(effortStatus(expected, atSplit: 2, headers: h), .expected)
        // Dropped before idx 2: furthest reached is idx 1 ("S1")
        let dropped = effort(bib: 3, times: [[t, t], [t, nil], [nil, nil], [nil, nil]], dropped: true)
        XCTAssertEqual(effortStatus(dropped, atSplit: 2, headers: h), .dropped(atStation: "S1"))
        // Not started: no times at all
        let none = effort(bib: 4, times: [[nil, nil], [nil, nil], [nil, nil], [nil, nil]])
        XCTAssertEqual(effortStatus(none, atSplit: 2, headers: h), .notStarted)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run the test-class command. Expected: FAIL — `effortStatus` / `EffortStatus` undefined.

- [ ] **Step 3: Append status logic to `RaceStatusViewModel.swift`**

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test-class command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: effort status derivation for aid-station view

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Field sorting + runner filter

**Files:**
- Modify: `OST Tracker/Swift/RaceStatusViewModel.swift`
- Modify (test): `OST TrackerTests/Swift/RaceStatusTests.swift`

**Interfaces:**
- Consumes: `EffortRow`, `SplitHeader`, `EffortStatus`, `effortStatus`,
  `furthestSplitIndex` (Tasks 1, 3).
- Produces:
  - `func sortedField(_ efforts: [EffortRow], atSplit idx: Int, headers: [SplitHeader]) -> [EffortRow]`
    — ordered: those **through** this split first (by arrival ascending), then
    **expected** (furthest desc, then bib asc), then **dropped** (furthest desc,
    then bib), then **not started** (bib asc).
  - `func matchEfforts(_ query: String, in efforts: [EffortRow]) -> [EffortRow]`
    — case-insensitive match on bib prefix OR first/last name substring; empty
    query → `[]`; results sorted by `overallRank` ascending.

- [ ] **Step 1: Write the failing tests**

Append to `RaceStatusTests.swift`:
```swift
extension RaceStatusTests {
    func test_sortedField_groupsAndOrders() {
        let h = headers(4)
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)
        let throughLate  = effort(bib: 10, times: [[late, late], [late, late], [late, nil], [nil, nil]])
        let throughEarly = effort(bib: 11, times: [[early, early], [early, early], [early, nil], [nil, nil]])
        let expected     = effort(bib: 12, times: [[early, early], [early, early], [nil, nil], [nil, nil]])
        let dropped      = effort(bib: 13, times: [[early, nil], [nil, nil], [nil, nil], [nil, nil]], dropped: true)
        let notStarted   = effort(bib: 14, times: [[nil, nil], [nil, nil], [nil, nil], [nil, nil]])

        let ordered = sortedField([dropped, expected, throughLate, notStarted, throughEarly],
                                  atSplit: 2, headers: h)
        XCTAssertEqual(ordered.map { $0.bibNumber }, [11, 10, 12, 13, 14])
    }

    func test_matchEfforts_bibAndName() {
        let t = Date()
        let raul = effort(bib: 28, times: [[t, t]])
        let tony = EffortRow(overallRank: 2, genderRank: 2, bibNumber: 6,
                             firstName: "Tony", lastName: "Lehner", absoluteTimes: [[t, t]])
        let all = [tony, raul]
        XCTAssertEqual(matchEfforts("28", in: all).map { $0.bibNumber }, [28])
        XCTAssertEqual(matchEfforts("leh", in: all).map { $0.bibNumber }, [6])
        XCTAssertEqual(matchEfforts("", in: all).count, 0)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run the test-class command. Expected: FAIL — `sortedField` / `matchEfforts` undefined.

- [ ] **Step 3: Append sorting + filter to `RaceStatusViewModel.swift`**

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test-class command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: aid-station field sorting + runner filter

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Presentation view models (runner progress + station field)

**Files:**
- Modify: `OST Tracker/Swift/RaceStatusViewModel.swift`
- Modify (test): `OST TrackerTests/Swift/RaceStatusTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces:
  - `struct RunnerStationLine { let label: String?; let elapsed: String; let timeOfDay: String }`
  - `struct RunnerStationRow { let title: String; let lines: [RunnerStationLine] }`
  - `struct RunnerSummary { let name: String; let bib: String; let detail: String }`
  - `struct RunnerProgress { let summary: RunnerSummary; let rows: [RunnerStationRow] }`
  - `func runnerProgress(_ e: EffortRow, spread: EventSpread) -> RunnerProgress`
  - `struct FieldRow { let bib: String; let name: String; let status: String; let time: String }`
  - `struct StationField { let countText: String; let rows: [FieldRow] }`
  - `func stationField(splitIndex: Int, spread: EventSpread) -> StationField`

Per-line rendering: for each header, one line per extension (`label` = the
extension name, e.g. `"In"`/`"Out"`; `nil` for a no-extension station). A present
time → `elapsed` = elapsed-from-start, `timeOfDay` = `HH:mm` plus a `" +Nd"`
suffix when the day offset is positive. A missing time → `elapsed = "—"`,
`timeOfDay = ""`.

- [ ] **Step 1: Write the failing tests**

Append to `RaceStatusTests.swift`:
```swift
extension RaceStatusTests {
    func test_runnerProgress_fromFixture() throws {
        let spread = try loadSpread()
        let beer = try XCTUnwrap(spread.efforts.first { $0.bibNumber == 28 })
        let progress = runnerProgress(beer, spread: spread)
        XCTAssertEqual(progress.summary.bib, "28")
        XCTAssertEqual(progress.summary.name, "Raul Beer")
        XCTAssertEqual(progress.rows.count, 18)
        // Start: one line, no label.
        XCTAssertEqual(progress.rows[0].lines.count, 1)
        XCTAssertNil(progress.rows[0].lines[0].label)
        XCTAssertEqual(progress.rows[0].lines[0].elapsed, "0:00")
        // Raspberry 1: In/Out → two labelled lines.
        XCTAssertEqual(progress.rows[1].lines.count, 2)
        XCTAssertEqual(progress.rows[1].lines[0].label, "In")
        XCTAssertEqual(progress.rows[1].lines[1].label, "Out")
        XCTAssertEqual(progress.rows[1].lines[0].elapsed, "1:05")
    }

    func test_stationField_fromFixture() throws {
        let spread = try loadSpread()
        let field = stationField(splitIndex: 2, spread: spread) // Antero
        XCTAssertEqual(field.rows.count, 151)
        XCTAssertTrue(field.countText.contains("of 151 through"))
        // The first row is whoever came through Antero earliest.
        XCTAssertEqual(field.rows.first?.status, "Through")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run the test-class command. Expected: FAIL — `runnerProgress` / `stationField` undefined.

- [ ] **Step 3: Append view models to `RaceStatusViewModel.swift`**

```swift
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

private func timeOfDayWithDay(_ t: Date, start: Date, tz: TimeZone) -> String {
    let clock = RaceStatusFormat.timeOfDay(t, in: tz)
    let day = RaceStatusFormat.dayOffset(from: start, to: t, in: tz)
    return day > 0 ? "\(clock) +\(day)d" : clock
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
                                         timeOfDay: timeOfDayWithDay(date, start: start, tz: tz))
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

func stationField(splitIndex idx: Int, spread: EventSpread) -> StationField {
    let start = spread.eventStartTime
    let ordered = sortedField(spread.efforts, atSplit: idx, headers: spread.splitHeaders)
    var throughCount = 0
    let rows: [FieldRow] = ordered.map { e in
        let status = effortStatus(e, atSplit: idx, headers: spread.splitHeaders)
        let statusText: String
        let timeText: String
        switch status {
        case .through(let arrival):
            throughCount += 1
            statusText = "Through"
            timeText = RaceStatusFormat.elapsed(from: start, to: arrival)
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
    return StationField(countText: "\(throughCount) of \(spread.efforts.count) through",
                        rows: rows)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test-class command. Expected: PASS. If `rows[1].lines[0].elapsed` is not `"1:05"`, re-derive the expected value from the fixture (Raspberry 1 In − Start) and update the assertion to the actual minutes — the format logic is the unit under test, not the fixture's exact value.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: runner-progress + station-field view models

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: OSTBackend read endpoints

**Files:**
- Modify: `OST Tracker/Swift/OSTBackend.swift`

**Interfaces:**
- Consumes: `EventSpread`, `EventRef` (Task 1); existing `APIClient.get`,
  `ConnectivityChecker`, `JSONAPIDoc` (`APIModels.swift`).
- Produces, on `OSTBackend`:
  - `func fetchSpread(eventSlug: String, completion: @escaping (Result<EventSpread, Error>) -> Void)`
  - `func fetchEvents(inGroup groupId: String, completion: @escaping (Result<[EventRef], Error>) -> Void)`
  Both deliver on the main queue, after an autologin/connectivity check.

This task has no unit test (it performs live network I/O); it is verified by a clean build. The pure decode it relies on is already covered by Task 1.

- [ ] **Step 1: Add a generic decodable request + the two methods**

In `OSTBackend.swift`, add these methods inside the `OSTBackend` class (e.g. after `fetchNotExpected`):
```swift
    // MARK: - Race Status reads (typed)

    func fetchSpread(eventSlug: String,
                     completion: @escaping (Result<EventSpread, Error>) -> Void) {
        decodableRequest("events/\(eventSlug)/spread", as: EventSpread.self, completion: completion)
    }

    func fetchEvents(inGroup groupId: String,
                     completion: @escaping (Result<[EventRef], Error>) -> Void) {
        decodableRequest("event_groups/\(groupId)?include=events", as: JSONAPIDoc.self) { result in
            switch result {
            case .success(let doc):
                let refs = doc.included
                    .filter { $0.type == "events" }
                    .map { EventRef(slug: $0.attributes.slug ?? "", name: $0.attributes.name ?? "") }
                    .filter { !$0.slug.isEmpty }
                completion(.success(refs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Connectivity-checked (autologin) typed GET, decoded via `APIClient.get`,
    /// delivered on the main queue. Mirrors `request(_:completion:)` but Codable.
    private func decodableRequest<T: Decodable>(_ path: String, as type: T.Type,
                                                completion: @escaping (Result<T, Error>) -> Void) {
        checker.check { [client] loginError in
            if let loginError = loginError {
                DispatchQueue.main.async { completion(.failure(loginError)) }
                return
            }
            client.get(path, as: T.self) { result in
                DispatchQueue.main.async { completion(result) }
            }
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED. (Note: `JSONAPIResource.attributes` already exposes `name` and `slug`; no model change needed.)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: OSTBackend fetchSpread + fetchEvents(inGroup:)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Race Status view controller

**Files:**
- Create: `OST Tracker/ViewControllers/OSTRaceStatusViewController.swift`

**Interfaces:**
- Consumes: `OSTBackend.fetchEvents`/`fetchSpread` (Task 6), all Task 1–5 types,
  `OSTBaseViewController`, `SelectableOptionList`, `BottomSheetPicker`,
  `PrimaryButton`, `Theme`, `ostShowBlockingSpinner`/`ostHideBlockingSpinner`/
  `ostPresentAlert`, `CurrentCourse`.
- Produces: `final class OSTRaceStatusViewController: OSTBaseViewController` with a
  no-arg `init()` (instantiated from the drawer menu via `[[OSTRaceStatusViewController alloc] init]`).

No unit test (UIKit screen); verified by build and by the user on-device.

- [ ] **Step 1: Create `OSTRaceStatusViewController.swift`**

```swift
import UIKit

/// Read-only "race state" screen. Manual refresh. Two modes on one page:
/// By Runner (search an effort → their splits) and By Aid Station (pick a split →
/// the whole field). Event selector hides when the group has one event.
final class OSTRaceStatusViewController: OSTBaseViewController,
                                         UITableViewDataSource, UITableViewDelegate,
                                         UITextFieldDelegate {

    private enum Mode: Int { case runner = 0, station = 1 }

    private enum DisplayRow {
        case runnerMatch(EffortRow)
        case runnerStation(RunnerStationRow)
        case fieldRow(FieldRow)
        case message(String)
    }

    // State
    private var events: [EventRef] = []
    private var selectedEvent: EventRef?
    private var spread: EventSpread?
    private var mode: Mode = .runner
    private var selectedEffort: EffortRow?
    private var searchText = ""
    private var selectedSplitIndex: Int?
    private var rows: [DisplayRow] = []

    private var groupId: String { CurrentCourse.getCurrentCourse()?.eventGroupId ?? "" }

    // Views
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let eventList = SelectableOptionList(label: "Event")
    private let modeControl = UISegmentedControl(items: ["By Runner", "By Aid Station"])
    private let searchField = UITextField()
    private let stationButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    init() { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if spread == nil { loadEvents() }
    }

    // MARK: - Loading

    private func loadEvents() {
        guard !groupId.isEmpty else {
            infoLabel.text = "No event selected"
            return
        }
        ostShowBlockingSpinner()
        OSTBackend.shared.fetchEvents(inGroup: groupId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure:
                self.ostHideBlockingSpinner()
                self.ostPresentAlert(title: "Error", message: "Couldn't load events.")
            case .success(let refs):
                self.events = refs
                self.eventList.options = refs.map { $0.name }
                self.eventList.isHidden = refs.count <= 1
                let first = refs.first
                self.selectedEvent = first
                if let first = first { self.eventList.select(first.name) }
                self.loadSpread()
            }
        }
    }

    private func loadSpread() {
        guard let event = selectedEvent else { ostHideBlockingSpinner(); return }
        ostShowBlockingSpinner()
        OSTBackend.shared.fetchSpread(eventSlug: event.slug) { [weak self] result in
            guard let self = self else { return }
            self.ostHideBlockingSpinner()
            switch result {
            case .failure:
                self.ostPresentAlert(title: "Error", message: "Couldn't load race data.")
            case .success(let spread):
                self.spread = spread
                self.selectedEffort = nil
                self.selectedSplitIndex = nil
                self.searchField.text = ""; self.searchText = ""
                self.reload()
            }
        }
    }

    // MARK: - Actions

    @objc private func onRefresh() { loadSpread() }

    @objc private func onModeChanged() {
        mode = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .runner
        updateControlVisibility()
        reload()
    }

    @objc private func onStationTapped() {
        guard let spread = spread else { return }
        let titles = spread.splitHeaders.map { $0.title }
        let current = selectedSplitIndex.flatMap { titles.indices.contains($0) ? titles[$0] : nil }
        BottomSheetPicker.present(from: self, title: "Aid Station", options: titles,
                                  selected: current) { [weak self] choice in
            self?.selectedSplitIndex = titles.firstIndex(of: choice)
            self?.updateStationButtonTitle()
            self?.reload()
        }
    }

    @objc private func onSearchChanged() {
        searchText = searchField.text ?? ""
        if !searchText.isEmpty { selectedEffort = nil }
        reload()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }

    private func onEventChosen(_ name: String) {
        guard let ref = events.first(where: { $0.name == name }), ref.slug != selectedEvent?.slug else { return }
        selectedEvent = ref
        loadSpread()
    }

    // MARK: - Rendering

    private func updateControlVisibility() {
        searchField.isHidden = (mode != .runner)
        stationButton.isHidden = (mode != .station)
    }

    private func updateStationButtonTitle() {
        let name = selectedSplitIndex
            .flatMap { spread?.splitHeaders.indices.contains($0) == true ? spread?.splitHeaders[$0].title : nil }
        stationButton.setTitle("Aid Station: \(name ?? "Choose") ▾", for: .normal)
    }

    private func reload() {
        guard let spread = spread else { rows = [.message("Loading…")]; tableView.reloadData(); return }
        switch mode {
        case .runner:
            if let effort = selectedEffort, searchText.isEmpty {
                let progress = runnerProgress(effort, spread: spread)
                infoLabel.text = "\(progress.summary.name)  #\(progress.summary.bib)\n\(progress.summary.detail)"
                rows = progress.rows.map { .runnerStation($0) }
            } else {
                let matches = matchEfforts(searchText, in: spread.efforts)
                infoLabel.text = searchText.isEmpty ? "Type a bib or name to find a runner."
                                                    : "\(matches.count) match\(matches.count == 1 ? "" : "es")"
                rows = matches.isEmpty ? [.message(searchText.isEmpty ? "" : "No runners match.")]
                                       : matches.map { .runnerMatch($0) }
            }
        case .station:
            guard let idx = selectedSplitIndex else {
                infoLabel.text = "Pick an aid station."
                rows = [.message("Choose an aid station above.")]
                break
            }
            let field = stationField(splitIndex: idx, spread: spread)
            infoLabel.text = "\(spread.splitHeaders[idx].title) — \(field.countText)"
            rows = field.rows.map { .fieldRow($0) }
        }
        tableView.reloadData()
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "rs")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "rs")
        cell.backgroundColor = .clear
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.textColor = Theme.label
        cell.detailTextLabel?.textColor = Theme.secondaryLabel
        cell.accessoryType = .none
        cell.selectionStyle = .none

        switch rows[indexPath.row] {
        case .runnerMatch(let e):
            cell.textLabel?.text = "#\(e.bibNumber)  \(e.fullName)"
            cell.detailTextLabel?.text = e.flexibleGeolocation
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .runnerStation(let r):
            cell.textLabel?.text = r.title
            cell.detailTextLabel?.text = r.lines.map { line -> String in
                let prefix = line.label.map { "\($0)  " } ?? ""
                let tod = line.timeOfDay.isEmpty ? "" : "   \(line.timeOfDay)"
                return "\(prefix)\(line.elapsed)\(tod)"
            }.joined(separator: "\n")
        case .fieldRow(let f):
            let time = f.time.isEmpty ? "" : "   \(f.time)"
            cell.textLabel?.text = "#\(f.bib)  \(f.name)"
            cell.detailTextLabel?.text = "\(f.status)\(time)"
        case .message(let m):
            cell.textLabel?.text = m
            cell.detailTextLabel?.text = nil
            cell.textLabel?.textColor = Theme.secondaryLabel
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .runnerMatch(let e) = rows[indexPath.row] {
            selectedEffort = e
            searchField.text = ""; searchText = ""
            searchField.resignFirstResponder()
            reload()
        }
    }

    // MARK: - UI construction

    private func buildUI() {
        titleLabel.text = "Race Status"
        titleLabel.font = Theme.Font.title
        titleLabel.textColor = Theme.label

        let refresh = UIButton(type: .system)
        refresh.setTitle("⟳ Refresh", for: .normal)
        refresh.setTitleColor(Theme.tint, for: .normal)
        refresh.titleLabel?.font = Theme.Font.button
        refresh.addTarget(self, action: #selector(onRefresh), for: .touchUpInside)

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), refresh])
        titleRow.alignment = .center

        eventList.onSelect = { [weak self] name in self?.onEventChosen(name) }
        eventList.isHidden = true

        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(onModeChanged), for: .valueChanged)

        searchField.placeholder = "Bib or name"
        searchField.borderStyle = .roundedRect
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.clearButtonMode = .whileEditing
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(onSearchChanged), for: .editingChanged)
        searchField.font = Theme.Font.field

        stationButton.setTitleColor(Theme.tint, for: .normal)
        stationButton.titleLabel?.font = Theme.Font.field
        stationButton.contentHorizontalAlignment = .left
        stationButton.addTarget(self, action: #selector(onStationTapped), for: .touchUpInside)
        stationButton.isHidden = true
        updateStationButtonTitle()

        infoLabel.font = Theme.Font.caption
        infoLabel.textColor = Theme.secondaryLabel
        infoLabel.numberOfLines = 0

        let controls = UIStackView(arrangedSubviews: [titleRow, eventList, modeControl,
                                                       searchField, stationButton, infoLabel])
        controls.axis = .vertical
        controls.spacing = 12
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.separatorColor = Theme.separator
        view.addSubview(tableView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            controls.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Theme.Metric.horizontalInset),
            controls.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Theme.Metric.horizontalInset),

            tableView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updateControlVisibility()
    }
}
```

- [ ] **Step 2: Register the new file**

```bash
ruby scripts/add_file_to_targets.rb "OST Tracker/ViewControllers/OSTRaceStatusViewController.swift" "OST Remote" "OST Remote Dev"
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Race Status view controller (runner + aid-station views)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Wire the screen into the drawer menu

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTRightMenuViewController.m`
- Modify: `OST Tracker/ViewControllers/OSTRightMenuViewController.xib`

**Interfaces:**
- Consumes: `OSTRaceStatusViewController` (Task 7); the existing
  `AppDelegate.getInstance.rightMenuVC` drawer.
- Produces: a "Race Status" menu button that sets the drawer's center VC.

- [ ] **Step 1: Add the `onRaceStatus:` action**

In `OSTRightMenuViewController.m`, add this method immediately after `onLiveReads:` (after its closing `}` near line 165), mirroring it:
```objc
- (IBAction)onRaceStatus:(id)sender
{
    OSTRaceStatusViewController *controller = [[OSTRaceStatusViewController alloc] init];
    [AppDelegate getInstance].rightMenuVC.centerViewController = controller;
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}
```

- [ ] **Step 2: Add the button to the XIB**

In `OSTRightMenuViewController.xib`, find the "Live Reads" button (`id="LiV-Rd-001"`, the `<button ... title="Live Reads">` block at frame `y="461"`). Immediately after its closing `</button>`, insert a new button:
```xml
                        <button opaque="NO" tag="6" contentMode="scaleToFill" fixedFrame="YES" contentHorizontalAlignment="left" contentVerticalAlignment="center" buttonType="roundedRect" lineBreakMode="middleTruncation" translatesAutoresizingMaskIntoConstraints="NO" id="RcS-St-001">
                            <rect key="frame" x="81" y="516" width="225" height="50"/>
                            <autoresizingMask key="autoresizingMask" flexibleMinX="YES" flexibleMaxY="YES"/>
                            <fontDescription key="fontDescription" type="system" pointSize="30"/>
                            <state key="normal" title="Race Status">
                                <color key="titleColor" white="1" alpha="1" colorSpace="calibratedWhite"/>
                            </state>
                            <connections>
                                <action selector="onRaceStatus:" destination="-1" eventType="touchUpInside" id="RcS-St-002"/>
                            </connections>
                        </button>
```

Then register the button in the `buttonViews` outlet collection: find the block of
`<outletCollection property="buttonViews" .../>` lines (near the top of the file,
around line 22–27) and add, after the `destination="LiV-Rd-001"` line:
```xml
                <outletCollection property="buttonViews" destination="RcS-St-001" id="RcS-St-003"/>
```

- [ ] **Step 3: Build to verify it compiles and links**

Run the build command. Expected: BUILD SUCCEEDED (the XIB loads `RcS-St-001` and connects `onRaceStatus:`).

- [ ] **Step 4: Run the FULL test suite (regression)**

```bash
xcodebuild test -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad (9th generation)' 2>&1 | tail -30
```
Expected: TEST SUCCEEDED — all existing tests plus `RaceStatusTests` pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Race Status to the drawer menu

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Verification checklist (after Task 8)

- [ ] Full test suite green on `iPad (9th generation)`.
- [ ] App builds for both `OST Remote` and `OST Remote Dev` schemes.
- [ ] Manual (user, on-device/simulator): open the drawer → "Race Status" appears
      and opens the screen; with the test event the event selector is hidden;
      "By Runner" search by bib/name shows a runner's splits with elapsed + clock
      times and In/Out lines; "By Aid Station" lists the field with status tags;
      Refresh re-pulls.

## Notes for the implementer

- The menu XIB uses fixed-frame layout; the new button sits at `y=516` directly
  below Live Reads (`y=461`), within the scroll content size (668). If on-device
  the button overlaps or clips, adjust only the new button's `y` — do not
  restructure the XIB.
- `JSONAPIResource.attributes` (in `APIModels.swift`) already exposes `name` and
  `slug`; Task 6 relies on that. If a future field is needed, add it there (one line).
- All time math is timezone-correct via the offset parsed from `eventStartTime`;
  do not switch to `.current`/device time.
