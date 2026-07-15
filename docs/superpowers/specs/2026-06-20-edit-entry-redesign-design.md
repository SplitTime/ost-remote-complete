# Edit Entry screen — design-system redesign

**Date:** 2026-06-20
**Branch:** `edit-entry-redesign` (off `swiftui-rewrite`)
**Status:** Approved

## Goal

Rebuild `OSTEditEntryViewController` to use the shared Swift design system
(`Theme` / `PrimaryButton` / programmatic Auto Layout), matching the look and
construction of the already-redesigned screens (Login, Event Selection, Live
Reads, Race Status). This is a presentation change only — all data behavior is
preserved exactly.

## Approach

**Full programmatic rewrite.** Drop `OSTEditEntryViewController.xib`; build the
view hierarchy in code with Auto Layout pinned to the safe area, styled entirely
through `Theme`. No storyboard/XIB, no frame math (`.left`, `.centerX`,
`.width`).

The `@objc` surface stays identical so both call sites
(`OSTRunnerTrackerViewController`, `OSTReviewSubmitViewController`) keep working
untouched:

- `@objc var creatingNew: Bool`
- `@objc var entryHasBeenDeletedBlock: (() -> Void)?`
- `@objc var entryHasBeenUpdatedBlock: ((EffortModel?) -> Void)?`
- `@objc func configure(withEntry:)`
- Presented modally via `present(_:animated:)` — unchanged.

Both call sites construct with `OSTEditEntryViewController(nibName: nil, bundle:
nil)`. Today UIKit auto-loads the same-named XIB even with `nibName: nil`; after
this change there is no XIB, so the controller must build its view in
`loadView()` / `viewDidLoad()` instead. Call sites do not change.

## Layout (top to bottom)

The content lives in a `UIScrollView` so the number pad / pickers never clip it.
Horizontal insets use `Theme.Metric.horizontalInset` (28).

1. **Header bar** — `✕` close button (left, `Theme.tint`, wired to existing
   `onClose`) + course name as a title label (`Theme.Font.title`, sized to fit).
   Hairline (`Theme.separator`) underneath.
2. **Bib number** — a caption label "Bib number" (`Theme.Font.caption`,
   `secondaryLabel`) above a themed field (`fieldFill`, `Theme.Metric.fieldHeight`,
   `cornerRadius`, `NumberPadView` as `inputView`). Below it the runner-status
   line:
   - "Bib Found: <name>" in `Theme.success`
   - "Bib Not Found!" in `Theme.destructive`
   - empty when no bib, default `secondaryLabel`.
3. **Time + Date** — two themed fields side by side (equal width via a
   horizontal `UIStackView`), each with its own caption ("Time", "Date").
   - **Time** keeps `CustomUIDatePicker` (H:M:S wheels) as `inputView` plus the
     Cancel/Done toolbar accessory.
   - **Date** keeps `OSTDropDownField` in `.datePicker` mode, including the
     iOS 13.4+ `.wheels` preferred-style fix.
4. **Switch rows** — a `fieldFill` card containing settings-style rows (label
   left, `UISwitch` right), a hairline between rows:
   - **"Dropped / Time Cut"** → backs `stoppedHere`; ON ⇒ `stoppedHere = "true"`.
   - **"With pacer"** → backs `withPacer`; ON ⇒ `withPacer = "true"`. This row is
     only shown when `CurrentCourse.getCurrentCourse()?.monitorPacers` is true
     (same condition as today).
   - Both keep the `OSTSound.shared().play("ost-remote-switch-1")` click on
     toggle.
5. **Actions** —
   - `PrimaryButton` titled **"Update entry"** (or **"Create new entry"** when
     `creatingNew`).
   - Below it a borderless **"Delete entry"** button in `Theme.destructive`,
     hidden when `creatingNew`. Delete still confirms via `UIAlertController`
     ("This action cannot be undone." / Cancel / Delete-destructive).

## Behavior preserved (no change)

- Bib lookup via `EffortModel.mr_findFirst` and the found/not-found label.
- `-1` placeholder filtering on load (blank field when `bibNumber == "-1"`).
- Empty-bib block on create (`BibEntry.isRecordable`) with the "Bib Required"
  alert.
- `populateTimeAndFlags`: `entryTime` = date + time-of-day ms, `displayTime`,
  the `absoluteTime` / timezone-offset string, `withPacer` / `stoppedHere`
  strings, `fullName` from the matched effort.
- Create path: copies split/course identity fields from the source entry into a
  new `EntryModel`, fires `entryHasBeenUpdatedBlock`, saves, dismisses.
- Update path: applies bib (if non-empty) + time/flags, saves, dismisses, fires
  the update block.
- CoreData save via `mr_default()` process + `mr_saveOnlySelfAndWait`.
- `removeInputAssistant()` on the text fields; no floating auto-toolbar.

## Components

No new shared design-system components are required. A small **private**
`SwitchRow` helper lives inside the file (mirroring the private `SheetRow` in
`BottomSheetPicker.swift`): a label + `UISwitch`, a `valueChanged` callback, and
a `setOn(_:)`. If a second screen later needs it, promote it to `DesignSystem/`.

## Files

- **Rewrite:** `OST Tracker/ViewControllers/OSTEditEntryViewController.swift`
- **Delete:** `OST Tracker/ViewControllers/OSTEditEntryViewController.xib`
- Remove the XIB's PBX references from `project.pbxproj`.

## Testing

- The screen is UIKit/layout-heavy; visual correctness is validated by the user
  in the simulator (per project workflow).
- Automated check: the project must build green (`OST Remote` scheme). Existing
  `BibEntryTests` continue to cover the bib-recordable logic, which is unchanged.
- A lightweight smoke test may be added if it can construct the controller and
  call `configure(withEntry:)` without a live CoreData store; otherwise skipped
  to avoid coupling a presentation test to MagicalRecord.

## Out of scope

- No changes to the data model, the bib lookup logic, the time math, or the two
  call sites.
- No new appearance/theming options.
