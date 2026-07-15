# Prune Deleted Runners Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "Refresh Data" (and event selection) remove runners that were deleted from the server roster, so they stop showing as "Expected" on the cross-check screen forever.

**Architecture:** The roster import is additive-only today — both call sites loop over the response's `efforts` and `mr_import` (upsert) each, never deleting locals that vanished from the server. Add one generic, DRY reconcile method to the MagicalRecord shim (`mr_reconcile(fromIncluded:ofType:)`) that upserts present members **and prunes absent ones** by the entity's `relatedByAttribute`, then replace the duplicated loop at both call sites with a single call. DNS is already handled correctly by the server's `not_expected` endpoint and is out of scope.

**Tech Stack:** Swift 5 + Core Data, hosted on the native `CoreDataStack`; Obj-C `EffortModel` resolved at runtime in tests; XCTest via `xcodebuild`.

> **Note on the spec:** The spec proposed `EffortModel.reconcileRoster(fromIncluded:)`. During planning this was refined to a generic shim method `mr_reconcile(fromIncluded:ofType:)` on `NSManagedObject`. Same behavior and intent (upsert + prune by primary key), but it lives next to `mr_import` in `MagicalRecordShim.swift`, reuses the shim's existing private helpers, and needs no new files (so no `.pbxproj` target-membership edits, and the gem `xcodeproj` is unavailable). `EffortModel` inherits it: `EffortModel.mr_reconcile(fromIncluded: included, ofType: "efforts")`.

---

## File Structure

- **Modify:** `OST Tracker/Swift/MagicalRecordShim.swift` — add the `mr_reconcile(fromIncluded:ofType:)` class method to the existing `extension NSManagedObject` (alongside `mr_import`, `MR_truncateAll`). Reuses the file's existing private helpers `mrEntityDescription(in:)`, `mrFetch(predicate:sort:limit:)`, and the file-private free functions `mrValue(forKeyPath:in:)` / `mrConvert(_:for:)`.
- **Modify (tests):** `OST TrackerTests/Swift/MagicalRecordShimTests.swift` — add three test methods. Reuses the file's existing `setUpWithError`/`tearDownWithError` (temp on-disk store), the dynamic `effort` type, and the `effortJSON(id:bib:name:)` helper.
- **Modify (call site 1):** `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift` — `onRefreshData`, the efforts-import loop (currently lines 114–117).
- **Modify (call site 2):** `OST Tracker/ViewControllers/OSTEventSelectionViewController.swift` — event-details completion, the efforts-import loop (currently lines 332–335).

No new files. No `.pbxproj` changes.

---

## Task 1: Add the reconcile helper (TDD)

**Files:**
- Test: `OST TrackerTests/Swift/MagicalRecordShimTests.swift` (append methods inside the existing `final class MagicalRecordShimTests`)
- Modify: `OST Tracker/Swift/MagicalRecordShim.swift`

- [ ] **Step 1: Write the failing tests**

Append these three methods inside the existing `MagicalRecordShimTests` class (just before the closing `}` of the class). They reuse the existing `effort` computed property and `effortJSON(id:bib:name:)` helper already defined in that file.

```swift
    // MARK: - mr_reconcile (prune deleted roster entries)

    /// All effortId values currently in the store.
    private func allEffortIds() -> Set<String> {
        let all = (effort.mr_findAll(with: nil) as? [NSManagedObject]) ?? []
        return Set(all.compactMap { $0.value(forKey: "effortId") as? String })
    }

    func test_reconcile_prunesEffortsMissingFromResponse() {
        effort.mr_reconcile(fromIncluded: [effortJSON(id: "1", bib: 1, name: "Alice"),
                                           effortJSON(id: "2", bib: 2, name: "Bob"),
                                           effortJSON(id: "3", bib: 3, name: "Carol")],
                            ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "2", "3"])

        // Bob (id 2) was removed from the roster on the server.
        effort.mr_reconcile(fromIncluded: [effortJSON(id: "1", bib: 1, name: "Alice"),
                                           effortJSON(id: "3", bib: 3, name: "Carol")],
                            ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "3"], "A runner removed from the server roster must be pruned locally")
    }

    func test_reconcile_emptyEffortsLeavesRosterIntact() {
        effort.mr_reconcile(fromIncluded: [effortJSON(id: "1", bib: 1, name: "Alice"),
                                           effortJSON(id: "2", bib: 2, name: "Bob")],
                            ofType: "efforts")
        // A response carrying no efforts (partial / malformed) must NOT wipe the roster.
        let eventsOnly: [[String: Any]] = [["id": "471", "type": "events",
                                            "attributes": ["shortName": "L100"]]]
        effort.mr_reconcile(fromIncluded: eventsOnly, ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "2"], "Safety guard: no matching members must not prune")
    }

    func test_reconcile_unchangedRosterAddsAndRemovesNothing() {
        let roster = [effortJSON(id: "1", bib: 1, name: "Alice"),
                      effortJSON(id: "2", bib: 2, name: "Bob")]
        effort.mr_reconcile(fromIncluded: roster, ofType: "efforts")
        effort.mr_reconcile(fromIncluded: roster, ofType: "efforts")
        XCTAssertEqual(allEffortIds(), ["1", "2"])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"OST TrackerTests/MagicalRecordShimTests" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Test Case .*(passed|failed)|Executed .* test" | tail -30
```
Expected: a **compile error** — `value of type 'NSManagedObject.Type' has no member 'mr_reconcile'` (the method does not exist yet).

- [ ] **Step 3: Implement `mr_reconcile(fromIncluded:ofType:)`**

In `OST Tracker/Swift/MagicalRecordShim.swift`, inside `extension NSManagedObject`, add this method directly after the `mr_import(from:in:)` method (before the `// MARK: - Private helpers` line):

```swift
    /// Reconciles this entity's table against a JSON:API `included` array.
    /// Upserts every member whose `type` equals `type` (by the entity's
    /// `relatedByAttribute`, via `mr_import`), then deletes any existing row whose
    /// primary key is absent from that set — i.e. rows removed on the server.
    /// No-ops when no member matches `type`, so a partial or malformed response
    /// can't wipe the table.
    @objc(mr_reconcileFromIncluded:ofType:)
    class func mr_reconcile(fromIncluded included: [[String: Any]], ofType type: String) {
        let members = included.filter { ($0["type"] as? String) == type }
        guard !members.isEmpty else { return }

        let context = CoreDataStack.shared.viewContext
        guard let entity = mrEntityDescription(in: context),
              let primaryKey = entity.userInfo?["relatedByAttribute"] as? String,
              let primaryAttr = entity.attributesByName[primaryKey] else { return }
        let mappedKey = (primaryAttr.userInfo?["mappedKeyName"] as? String) ?? primaryKey

        var serverKeys = Set<String>()
        for object in members {
            if let raw = mrValue(forKeyPath: mappedKey, in: object),
               let value = mrConvert(raw, for: primaryAttr) {
                serverKeys.insert(String(describing: value))
            }
            _ = mr_import(from: object)
        }

        for case let managed as NSManagedObject in mrFetch(predicate: nil, sort: nil, limit: 0) {
            let key = managed.value(forKey: primaryKey).map { String(describing: $0) }
            if key == nil || !serverKeys.contains(key!) {
                context.delete(managed)
            }
        }

        context.processPendingChanges()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"OST TrackerTests/MagicalRecordShimTests" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Test Case .*(passed|failed)|Executed .* test" | tail -30
```
Expected: all `MagicalRecordShimTests` pass, including the three new `test_reconcile_*` cases. Final line shows `Executed N tests ... 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/MagicalRecordShim.swift" "OST TrackerTests/Swift/MagicalRecordShimTests.swift"
git commit -m "$(cat <<'EOF'
Add mr_reconcile to prune rows missing from a JSON:API response

Generic upsert-and-prune by relatedByAttribute, sibling to mr_import.
No-ops when no member matches the given type so a partial response can't
wipe the table. Tested against the real EffortModel on a temp store.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Wire both roster-import call sites to reconcile

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift` (Refresh Data)
- Modify: `OST Tracker/ViewControllers/OSTEventSelectionViewController.swift` (event selection)

No new unit test — these are view-controller wiring changes covered by the helper's tests (Task 1) and verified by a clean build plus the full offline suite staying green.

- [ ] **Step 1: Replace the import loop in Refresh Data**

In `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift`, in `onRefreshData`, replace this block:

```swift
            let included = root?["included"] as? [[String: Any]] ?? []
            for dataObject in included where (dataObject["type"] as? String) == "efforts" {
                EffortModel.mr_import(from: dataObject)
            }
```

with:

```swift
            let included = root?["included"] as? [[String: Any]] ?? []
            EffortModel.mr_reconcile(fromIncluded: included, ofType: "efforts")
```

Leave the rest of the method unchanged — the trailing `processPendingChanges()` / `mr_saveOnlySelfAndWait()` (lines ~136–137) still persists the `currentCourse` fields (`dataEntryGroups`, `monitorPacers`, `eventIdsAndSplits`, `eventShortNames`) set after this block.

- [ ] **Step 2: Replace the import loop in event selection**

In `OST Tracker/ViewControllers/OSTEventSelectionViewController.swift`, in the `getEventsDetails` completion, replace this block:

```swift
            let included = root?["included"] as? [[String: Any]] ?? []
            for dataObject in included where (dataObject["type"] as? String) == "efforts" {
                EffortModel.mr_import(from: dataObject)
            }
```

with:

```swift
            let included = root?["included"] as? [[String: Any]] ?? []
            EffortModel.mr_reconcile(fromIncluded: included, ofType: "efforts")
```

Leave the rest unchanged — the trailing save (lines ~361–362) still persists the `currentCourse` fields set afterward.

- [ ] **Step 3: Build to verify both call sites compile**

Run:
```bash
xcodebuild build -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -20
```
Expected: `** BUILD SUCCEEDED **`, no `error:` lines.

- [ ] **Step 4: Run the full offline test suite to confirm no regression**

Run:
```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"OST TrackerTests" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Test Case .*(passed|failed)|Executed .* test|TEST (SUCCEEDED|FAILED)|error:" | tail -40
```
Expected: `** TEST SUCCEEDED **`, `0 failures`. (Live API tests are gated behind `OST_LIVE_TESTS=1` and stay skipped.)

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTUtilitiesViewController.swift" \
        "OST Tracker/ViewControllers/OSTEventSelectionViewController.swift"
git commit -m "$(cat <<'EOF'
Prune deleted runners on Refresh Data and event selection

Both roster-import call sites now reconcile (upsert + prune) instead of
upsert-only, so a runner removed from the server roster no longer lingers
as "Expected" on the cross-check screen. DNS already handled via
not_expected — unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

- **Spec coverage:**
  - *Prune deleted efforts on roster import* → Task 1 (`mr_reconcile`) + Task 2 (both call sites). ✓
  - *Shared helper, no duplicated loop* → Task 2 replaces both loops with one call. ✓
  - *Safety guard against empty/malformed response* → `guard !members.isEmpty` + `test_reconcile_emptyEffortsLeavesRosterIntact`. ✓
  - *Upsert behavior unchanged* → reconcile delegates to existing `mr_import`; `test_reconcile_unchangedRosterAddsAndRemovesNothing`. ✓
  - *DNS untouched / out of scope* → no change to `OSTBackend.fetchNotExpected` or `OSTCrossCheckViewController`. ✓
  - *Leave EntryModel / CrossCheckEntriesModel alone* → reconcile only fetches/deletes the receiving entity (`EffortModel`); no other entity touched. ✓
  - *Tests: remove-one, empty, unchanged* → all three present in Task 1. ✓
- **Placeholder scan:** none — every code and command step is concrete.
- **Type consistency:** method is `mr_reconcile(fromIncluded:ofType:)` (Swift) / `mr_reconcileFromIncluded:ofType:` (`@objc`) everywhere; called as `EffortModel.mr_reconcile(fromIncluded:ofType:)` at both call sites and `effort.mr_reconcile(fromIncluded:ofType:)` in tests; private helpers (`mrEntityDescription`, `mrFetch`, `mrValue`, `mrConvert`) match their existing signatures in `MagicalRecordShim.swift`.
