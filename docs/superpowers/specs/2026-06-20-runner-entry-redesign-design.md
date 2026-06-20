# Runner-Entry Screen — Design-Language Rebuild

**Date:** 2026-06-20
**Branch:** `worktree-runner-entry` (off `swiftui-rewrite`, merges back to `swiftui-rewrite`)
**Status:** Approved — autonomous execution to completion; user validates the running app afterward.

## Goal

Rebuild the app's core bib-entry screen (`OSTRunnerTrackerViewController`) in the new
design language (`Theme`, `PrimaryButton`-style buttons, system fonts, rounded corners,
light/dark) used by the already-modernized screens (`OSTLiveReadsViewController`,
`OSTEventSelectionViewController`). The current screen is the last major surface on the
old look: XIB-driven absolute frame-math, hardcoded Helvetica fonts, `GrayButton`
images, raw colors, and no dark-mode support.

This is a **full programmatic rebuild** with a single adaptive Auto Layout hierarchy —
the XIB and all manual frame-math are removed. Behavior is preserved exactly.

Out of scope (separate follow-up): the edit-entry sheet `OSTEditEntryViewController`.

## iOS 12 floor

Everything used is iOS 12-safe: Auto Layout (iOS 6+), `UIStackView` (iOS 9+),
`safeAreaLayoutGuide` (iOS 11+). Dark mode is the only iOS 13+ piece and degrades for
free: `Theme.dynamic(...)` resolves to the light value on iOS 12. No SF Symbols used as
sole affordances. `OSTLiveReadsViewController` already proves this pattern ships to the
iOS 12 floor.

## Contracts that MUST be preserved

These are external touch-points; breaking them breaks other modules:

- `@objc(OSTRunnerTrackerViewController)` class, instantiated via
  `initWithNibName:nil bundle:nil` in `AppDelegate.m`. With no XIB present, build the
  hierarchy in code (`loadView` / `viewDidLoad`). No nib auto-loads once the XIB is gone.
- `txtBibNumber` stays an `@objc`-visible `UITextField` property —
  `OSTRightMenuViewController.m` calls `becomeFirstResponder` on it.
- `@objc func cleanData()` — keep (externally reachable).
- `OSTRunnerTrackerViewControllerDidRegisterBibNotification` — keep posting on record.
- KVO on `txtBibNumber`'s `text` keypath — the embedded `NumberPadView` mutates `.text`
  programmatically, so editingChanged would not fire. Keep the observer add/remove
  lifecycle (and the add/remove guards inside `onEntryButton`).
- All sounds (`OSTSound`), the right-menu/drawer toggle, and the edit-sheet present flow.
- Business logic methods carry over essentially unchanged: `onEntryButton`,
  `updateBibInfo`, `onButtonPacer`, `onBtnStopped`, `onRunnerInfo`, `onTick`,
  `runnerBadgeViewModel`, `saveContext`, `textField(_:shouldChangeCharactersIn:…)`
  (4-digit numeric limit). Only **view construction + layout** is rewritten.
- `OSTRunnerBadge` reused as-is, created programmatically via `OSTRunnerBadge(frame:)`
  (it self-loads its nib in `initWithFrame:`).

## New layout — one adaptive Auto Layout hierarchy

Root vertical `UIStackView` pinned to `safeAreaLayoutGuide`, top → bottom:

1. **Header bar** (`Theme.secondaryBackground`): station/split title (left) +
   **Menu** button (right) → existing `onRight` drawer toggle. Mirrors the LiveReads header.
2. **Display zone** (`Theme.background`):
   - Live clock `HH:mm:ss` (+ time-of-day) — large display font.
   - **Bib number** field (`txtBibNumber`) — large bold, center, 4-digit numeric.
   - Runner result line: name (`label`) + secondary info gender/age/event
     (`secondaryLabel`); **"Bib Not Found"** in `Theme.destructive`.
   - **Runner badge** (`OSTRunnerBadge`) for the last-recorded entry; tap → edit sheet.
3. **Toggle row**: **Stopped here** / **With pacer** as modern pill toggles (selected =
   `Theme.tint` filled, unselected = outlined). Pacer hidden when the course does not
   monitor pacers (existing `monitorPacers` check).
4. **Entry buttons**: **In / Out** as `PrimaryButton`-style filled buttons in a
   horizontal stack, each with its count badge overlaid. Must reproduce all permutations
   the old `viewWillAppear` handled: 1 in, 1 out, 1-in+1-out, 2-in, 2-out — driven by the
   same `entries`/`subSplitKind` data and the same `leftBitKey`/`rightBitKey` semantics.
5. **Number pad**: `NumberPadView`, themed.

### Adaptivity (constraints, not frame-math)

- **Portrait** (primary): the vertical stack above.
- **Landscape / iPad**: split display-zone vs number-pad via size class / orientation —
  number pad to the trailing half in landscape; scale clock/bib/button fonts up on `.pad`.
- All deleted: `view.width/2 - 4` math, per-orientation `viewWillTransition` /
  `viewWillAppear` frame juggling, the iPad sizing block, and the `applySafeAreaShift`
  shim (`safeAreaLayoutGuide` replaces it).

## Theme adoption

- Colors via `Theme`: `background`, `secondaryBackground`, `label`, `secondaryLabel`,
  `destructive`, `tint`, `separator`. Full light/dark; static-light on iOS 12.
- Fonts: system fonts. Add display-size roles to `Theme.Font` (e.g. `.clock`, `.bib`)
  rather than hardcoding sizes in the VC (DRY). Keep existing roles intact.
- Entry/toggle buttons: `Theme` tint + `Metric.cornerRadius`; drop `GrayButton` images.
- **`NumberPadView`**: move key colors from hardcoded white/black to
  `Theme.secondaryBackground` / `Theme.label` so the pad themes correctly (light on
  iOS 12). Shared component — verify its other use site (text-field `inputView`) still
  reads correctly after the change.

## Files

- **Rewrite:** `OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift`
- **Delete:** `OST Tracker/ViewControllers/OSTRunnerTrackerViewController.xib` and its
  PBX references (use the repo's `remove_file_from_xcodeproj.rb` helper).
- **Edit:** `OST Tracker/Swift/NumberPadView.swift` (theme keys).
- **Edit:** `OST Tracker/Swift/DesignSystem/Theme.swift` (add display font roles).

## Testing & verification

- Project builds clean for the `OST Remote` scheme (iOS Simulator).
- Existing unit tests still pass (`BibEntryTests`, `NumberPadViewTests`, etc.).
- Visual verification is handed to the user across: 1-button vs in/out vs 2-in/2-out;
  pacer on/off; bib-found vs not-found; recorded-badge state; portrait/landscape;
  iPhone/iPad; light/dark.

## Risks

- This is the critical screen; the entry-button permutation logic is the highest-risk
  area. Mitigation: keep the exact data-driven `leftBitKey`/`rightBitKey` semantics,
  reorganizing only how the buttons are positioned (stack vs frame-math).
- KVO lifecycle must stay balanced (add/remove) to avoid the known crash class; preserve
  the existing add/remove guards verbatim.
