# Block Empty-Bib Entries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the app from recording placeholder `"-1"` entries when a record button is tapped with an empty bib field — block the action entirely and give error feedback instead.

**Architecture:** Extract the empty-bib decision into a tiny pure function (`BibEntry.isRecordable(_:)`) so it is unit-testable without driving the IBAction-wired view controllers. Wire that function into the two creation paths: the tracker screen's `onEntryButton` (play error sound + early return) and the edit screen's "Create new entry" path (`onUpdate` `creatingNew` branch — show a brief alert + return). Existing `"-1"` sentinel filtering stays untouched for backward compatibility with already-stored placeholder entries.

**Tech Stack:** Swift + UIKit, iOS 12 deployment target, XCTest. Built from `OST Tracker.xcodeproj` (no CocoaPods/workspace). Module name for `@testable import`: `OST_Remote`.

## Global Constraints

- iOS 12.0 deployment floor; no new dependencies (zero-pod app).
- Build/test: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test` (substitute any available sim from `xcrun simctl list devices available`).
- Every new Swift source file must be added to BOTH app targets: `OST Remote` and `OST Remote Dev` (mirror the existing `NumberPadView.swift` entries in `project.pbxproj`).
- DO NOT remove or weaken `"-1"` filtering anywhere — it is an app-wide sentinel and users may already have `"-1"` entries in local Core Data. Untouched sites: `OSTReviewSubmitViewController.swift:306` & `:319`, `OSTBaseViewController.m:134`, `OSTReviewTableViewCell.m:32`.
- KVO GOTCHA: `txtBibNumber` has its `"text"` observer removed at the top of `onEntryButton` and only re-added at the very end. Any early return MUST re-add the observer first, or live roster lookup-on-keystroke silently dies for the screen's lifetime.

---

### Task 1: Extract the pure `BibEntry.isRecordable` rule (TDD)

**Files:**
- Create: `OST Tracker/Swift/BibEntry.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (add the new file to both app targets)
- Test: `OST TrackerTests/Swift/BibEntryTests.swift`

**Interfaces:**
- Produces: `enum BibEntry { static func isRecordable(_ bibText: String?) -> Bool }` — returns `false` for nil or empty text, `true` otherwise. Used by Tasks 2 and 3.

- [ ] **Step 1: Write the failing test**

Create `OST TrackerTests/Swift/BibEntryTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class BibEntryTests: XCTestCase {

    func test_isRecordable_isFalse_forNil() {
        XCTAssertFalse(BibEntry.isRecordable(nil))
    }

    func test_isRecordable_isFalse_forEmptyString() {
        XCTAssertFalse(BibEntry.isRecordable(""))
    }

    func test_isRecordable_isTrue_forNonEmptyBib() {
        XCTAssertTrue(BibEntry.isRecordable("42"))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — `cannot find 'BibEntry' in scope`.

- [ ] **Step 3: Create the implementation file**

Create `OST Tracker/Swift/BibEntry.swift`:

```swift
//
//  BibEntry.swift
//  OST Tracker
//
//  Pure, side-effect-free rules for bib entry creation, shared by the tracker and
//  edit-entry screens. Extracted so the empty-bib block is unit-testable without
//  driving the IBAction-wired view controllers.
//

import Foundation

enum BibEntry {

    /// A bib can be recorded only when the field holds at least one character.
    /// An empty or nil field is blocked: no entry is created.
    static func isRecordable(_ bibText: String?) -> Bool {
        !(bibText?.isEmpty ?? true)
    }
}
```

- [ ] **Step 4: Add the file to both app targets in `project.pbxproj`**

Mirror the four `NumberPadView.swift` entry kinds, generating two fresh 24-hex-char UUIDs (one PBXBuildFile per target). Add:
- Two `PBXBuildFile` lines (next to the existing `NumberPadView.swift in Sources` build files) — one for `OST Remote`, one for `OST Remote Dev`.
- One `PBXFileReference` (path `OST Tracker/Swift/BibEntry.swift`, `lastKnownFileType = sourcecode.swift`).
- One entry in the Swift group's `children` (next to the `NumberPadView.swift` file-reference child).
- One entry in EACH target's `PBXSourcesBuildPhase` `files` list (next to the two `NumberPadView.swift in Sources` lines at the build-phase sites).

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS — `BibEntryTests` all green, project compiles (confirms the new file is in the test-host target).

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/Swift/BibEntry.swift" "OST TrackerTests/Swift/BibEntryTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add pure BibEntry.isRecordable rule with tests"
```

---

### Task 2: Block empty bib in the tracker screen (`onEntryButton`)

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift` (`onEntryButton(_:)`, ~lines 279–293)

**Interfaces:**
- Consumes: `BibEntry.isRecordable(_:)` from Task 1.

- [ ] **Step 1: Add the early-return guard at the top of `onEntryButton`**

In `onEntryButton(_:)`, immediately after the existing `UIDevice.current.playInputClick()` line (line 281), insert the block — it MUST run before `EntryModel.mr_createEntity()` and MUST re-add the KVO observer before returning:

```swift
        if !BibEntry.isRecordable(txtBibNumber.text) {
            OSTSound.shared().play("ost-remote-bib-not-found")
            txtBibNumber.addObserver(self, forKeyPath: "text", options: [.new, .old], context: nil)
            return
        }
```

- [ ] **Step 2: Collapse the now-dead `-1` branch**

Replace the `if/else` at lines 288–293:

```swift
        if txtBibNumber.text?.isEmpty ?? true {
            entry.bibNumber = "-1"
            racer = nil
        } else {
            entry.bibNumber = txtBibNumber.text
        }
```

with the single line (bib is guaranteed non-empty after the Step 1 guard):

```swift
        entry.bibNumber = txtBibNumber.text
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift"
git commit -m "feat: block empty-bib record on tracker screen"
```

---

### Task 3: Block empty bib in the edit screen's "Create new entry" path (`onUpdate`)

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTEditEntryViewController.swift` (`onUpdate(_:)`, `creatingNew` branch, ~lines 156–176)

**Interfaces:**
- Consumes: `BibEntry.isRecordable(_:)` from Task 1.

Note: Only the `creatingNew` branch changes. The existing-entry edit path (lines 178–186) is left untouched.

- [ ] **Step 1: Add the empty-bib guard at the top of the `creatingNew` branch**

Inside `if creatingNew {`, before the `guard let source = entry, let newEntry = ...` line (line 157), insert:

```swift
            if !BibEntry.isRecordable(txtBibNumber.text) {
                let alert = UIAlertController(title: "Bib Required",
                                              message: "Enter a bib number to create a new entry.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
```

- [ ] **Step 2: Collapse the now-dead `-1` assignment**

Replace line 159:

```swift
            newEntry.bibNumber = (txtBibNumber.text?.isEmpty ?? true) ? "-1" : txtBibNumber.text
```

with (bib is guaranteed non-empty after the Step 1 guard):

```swift
            newEntry.bibNumber = txtBibNumber.text
```

Then delete the now-redundant re-assignment at line 168:

```swift
            if !(txtBibNumber.text?.isEmpty ?? true) { newEntry.bibNumber = txtBibNumber.text }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTEditEntryViewController.swift"
git commit -m "feat: block empty-bib on edit-entry create-new path"
```

---

### Task 4: Full verification

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: TEST SUCCEEDED — all tests including `BibEntryTests` pass.

- [ ] **Step 2: Confirm `"-1"` filtering is intact (no regressions)**

Run: `grep -rn '"-1"' "OST Tracker"`
Expected: the four documented filter sites (`OSTReviewSubmitViewController.swift` x2, `OSTBaseViewController.m`, `OSTReviewTableViewCell.m`) are unchanged; the only removed `"-1"` occurrences are the two creation branches.

- [ ] **Step 3: Hand to user for manual simulator verification**

User checks: empty field + tap In/Out → nothing recorded + error sound + live lookup still works on subsequent keystrokes; non-empty bib → records normally; edit screen "Create new entry" with empty bib → alert shown, no entry created.

---

## Self-Review

- **Spec coverage:** Primary change (tracker `onEntryButton`) → Task 2. KVO re-add gotcha → Task 2 Step 1. Secondary scope (edit create-new) confirmed YES by user → Task 3. Pure-function + unit test (user choice) → Task 1. `"-1"` preservation → Global Constraints + Task 4 Step 2. ✓
- **Placeholder scan:** No TODO/TBD; all steps show concrete code/commands. ✓
- **Type consistency:** `BibEntry.isRecordable(_ bibText: String?) -> Bool` used identically in Tasks 2 and 3. ✓
