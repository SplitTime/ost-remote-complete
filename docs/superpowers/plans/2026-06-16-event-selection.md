# Event / Aid Selection (Swift + UIKit, iOS 12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Execute inline. Steps use `- [ ]`.
> **⚠️ Verification dependency:** this screen is interactive + data-coupled. Full verification needs driving the simulator UI (pick event → aid → confirm → tracker populates), which requires **macOS Accessibility** granted to the controlling tool, OR a human pass. Do not mark "done" on behavior without one of those.

**Goal:** Replace `OSTEventSelectionViewController` (Obj-C/XIB) with a Swift + UIKit screen (iOS 12, Modern-iOS style, safe-area correct): pick an event, then an aid station/split, then download details and continue to the tracker — **with no change to the CoreData state** the tracker reads.

## Key architecture decision — reuse the Obj-C data layer

The old confirm flow does a MagicalRecord import (`EffortModel MR_importFromObject`) and sets ~11 `CurrentCourse` fields (`dataEntryGroups, eventId, splitId, splitName, eventName, multiLap, splitAttributes, monitorPacers, eventGroupId, eventIdsAndSplits, eventShortNames`) that the **still-Obj-C tracker depends on**. Reimplementing that import in Swift now is high-risk and unverifiable until the tracker is also migrated.

**Decision:** rewrite only the **UI** in Swift+UIKit. For data, **call the existing Obj-C logic via bridging**:
- Extract the old VC's event-load and confirm/import bodies into reusable Obj-C methods (e.g. a small `OSTEventSelectionDataSource` category/class, or keep methods on the old VC and call them), OR call `[[AppDelegate getInstance].getNetworkManager getEvents…/getEventsDetails…]` and run the same CurrentCourse/EffortModel population in an Obj-C helper.
- Net effect: identical CoreData writes (literally the same code), modern Swift UI, safe-area fixed.
- The data layer gets ported to pure Swift in a later milestone, once the tracker no longer reads `CurrentCourse` directly.

## Tasks

### Task 1: Extract Obj-C data helper (no behavior change)
- [ ] Move the event-load (`getEvents`) and the confirm/import block (`getEventsDetails` → CurrentCourse + EffortModel import → `loadLeftMenu`) out of `OSTEventSelectionViewController.m` into a reusable Obj-C class `OSTEventSelectionService` with methods:
  - `- (void)loadEventsWithCompletion:(void(^)(NSArray<OSTEventOption*>*, NSError*))completion;`
  - `- (void)selectSplitTitle:(NSString*)title forEvent:(OSTEventOption*)event;` (the split-pick CurrentCourse update at lines ~260-272)
  - `- (void)confirmEvent:(OSTEventOption*)event completion:(void(^)(NSError*))completion;` (the lines 289-343 import + loadLeftMenu)
- [ ] Expose to Swift via the bridging header. Build the old VC against the service to prove parity. Commit.

### Task 2: EventOption + split list models (Swift, testable)
- [ ] A Swift (or Obj-C-bridged) `EventOption` (eventId, eventGroupId, name, multiLap) and the split/aid-station title list derivation. Unit-test the event-list mapping against `Verification/fixtures/event_groups_list.json` (extends existing APIParsing). Commit.

### Task 3: EventSelectionViewController (Swift + UIKit)
- [ ] Programmatic screen, content pinned to `safeAreaLayoutGuide`, Modern-iOS style: "Select Event" picker, "Select Aid Station" picker (UIPickerView or a tap-to-choose list — replace IQDropDownTextField), a download/progress indicator, a confirm button. Drive via `OSTEventSelectionService`.
- [ ] On confirm: call the service (same CoreData writes), which calls `loadLeftMenu`. Build green. Commit.

### Task 4: Wire in
- [ ] `LoginViewController` success presents the Swift `EventSelectionViewController` instead of the Obj-C one (update the bridging usage in `LoginViewController.swift`). Build green. Commit.

### Task 5: Verify (NEEDS UI automation or human)
- [ ] Simulator: screenshot the new screen (assert safe-area correct, Modern-iOS look).
- [ ] Drive: log in → pick "Test Lonesome 100" → pick an aid station (e.g. Raspberry 1) → confirm → confirm the tracker opens populated (same as old app). Requires Accessibility-granted UI automation or a human pass.
- [ ] Save before/after screenshots to `Verification/screenshots/`. Commit.

## Self-review
- Preserves CoreData behavior exactly (reuses Obj-C import). ✓
- iOS 12 / UIKit / safe-area. ✓
- Verification of the data-coupled confirm flow is gated on UI automation/human — flagged above.
