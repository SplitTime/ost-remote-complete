# Upgrade Review / Sync to the DesignSystem — Design

**Goal:** Replace the XIB-driven Review/Sync screen (`OSTReviewSubmitViewController`)
with a fully programmatic screen built on the shared DesignSystem (`Theme`,
`PrimaryButton`, `BottomSheetPicker`, `OSTToast`), matching the rest of the
modernized app. This is a **view-layer rewrite only** — all data, sync, export,
and edit-entry logic is preserved verbatim.

**Tech stack:** Swift + UIKit (iOS 12 floor), programmatic Auto Layout, `Theme`
design system, MagicalRecord-via-bridging CoreData, XCTest.

---

## 1. Scope & architecture

Full rewrite to the DesignSystem (chosen over restyle-in-place).

**Retire (delete):**
- `OSTReviewSubmitViewController.xib`
- `OSTReviewTableViewCell.{h,m,xib}`
- `OSTReviewSectionHeader.{h,m,xib}`
- The `IQDropDownField` sort field (`txtSortBy` / `OSTDropDownField`) on this screen
- The `GrayButton`-image Sync button styling
- The `liftBottomBarAboveHomeIndicator()` + `ostApplySafeAreaFix()` /
  `ostPositionBadgeAtMenu()` frame math — replaced by real Auto Layout with
  safe-area anchors.

**Build (programmatic Swift):**
- Rewritten `OSTReviewSubmitViewController` (keeps `@objc(OSTReviewSubmitViewController)`
  so existing navigation via `AppDelegate.showReview()` still resolves).
- `ReviewEntryCell : UITableViewCell` — design-system entry row.
- `ReviewSectionHeaderView : UITableViewHeaderFooterView` — design-system split header.

**Reuse (no new shared abstractions):** `Theme`, `PrimaryButton`,
`BottomSheetPicker`, `OSTToast`.

**Preserve unchanged:** `loadData()` and its sort logic, the `AutoSyncController`
delegate overrides, `updateSyncBadge`, CSV export, and edit-entry navigation
(`OSTEditEntryViewController`). The unsynced-count badge + AutoSync observer
wiring stay intact.

**Concurrency note:** The in-flight "Dissolve Utilities into the Right Menu" plan
(`docs/superpowers/plans/2026-06-20-dissolve-utilities-into-menu.md`) also touches
base-VC badge wiring, but on the *drawer's* `reviewSyncRow` — a different object.
No collision; both keep their own `updateSyncBadge` / `syncManager…` overrides.

---

## 2. Layout

A vertical structure pinned to `view.safeAreaLayoutGuide`:

```
┌─────────────────────────────────────────────┐
│  HEADER                                       │
│  [≡ menu]  Event Name            [⤴ Export]   │  ← unsynced badge over menu
│  Sort: [ Time Entered          ▾ ]            │  ← tap → BottomSheetPicker
├─────────────────────────────────────────────┤
│  LIST (UITableView, grouped)                  │
│   ┌── Start Entries ──────────────────────┐   │  ← ReviewSectionHeaderView
│   │  7:42:10   Jane Doe        #142   In   │   │  ← ReviewEntryCell
│   │  7:43:55   Bib not found   …     Out   │   │
│   └────────────────────────────────────────┘   │
│   ┌── Aid 2 Entries ───────────────────────┐   │
│   │  …                                      │   │
├─────────────────────────────────────────────┤
│  BOTTOM BAR (pinned, safe-area aware)         │
│   [        Sync 12 Times        ]             │  ← PrimaryButton, full width
└─────────────────────────────────────────────┘
```

**Header:**
- Leading: existing menu/hamburger button (`onRightMenu`), with the unsynced-count
  badge overlaid on it (replaces `ostPositionBadgeAtMenu` with a constrained badge).
- Center/leading title: event name (`Theme.Font.title`-scale, `Theme.label`).
- Trailing: **Export** control — `UIButton` with SF Symbol `square.and.arrow.up`,
  tinted `Theme.tint`. Plain button (no `UIMenu`; iOS 12-safe). Calls the existing
  `onExport`.
- Sort control: a tappable field/row showing `Sort: <current>` with a trailing
  chevron. Tapping presents `BottomSheetPicker.present(from:title:"Sort By",
  options:["Name","Time Displayed","Time Entered","Bib #"], selected:<current>,
  onSelect:)`. Selection persists to `UserDefaults` key `reviewScreenPicklistValue`
  (same key/semantics as today) and calls `loadData()`.

**List:**
- `UITableView` (`.grouped`), `Theme.background`.
- Section header = `ReviewSectionHeaderView`: split title as `"<title> Entries:"`,
  `Theme.Font.caption`/section-header styling, `Theme.secondaryLabel`,
  `Theme.background`/`secondaryBackground`.
- Row = `ReviewEntryCell` (see §3).

**Bottom bar:**
- Single full-width `PrimaryButton` (`.primary`), pinned above the safe-area bottom
  with real constraints (no frame math). The table's `contentInset.bottom` accounts
  for the bar via Auto Layout (bar height + spacing), so last rows scroll clear.

---

## 3. ReviewEntryCell

Programmatic cell, all colors/fonts from `Theme`. Displays the same data the
legacy cell did:

| Element      | Source                       | Style                                  |
|--------------|------------------------------|----------------------------------------|
| Time         | `entry.displayTime`          | `Theme.Font.field`, mono-ish, leading  |
| Name         | `entry.fullName`             | `Theme.label`; empty → "Bib not found" |
| Bib          | `#<bibNumber>` (hide if `-1`)| `Theme.secondaryLabel`                 |
| In/Out       | `entry.bitKey.capitalized`   | `Theme.secondaryLabel`, trailing       |
| Pacer icon   | `entry.withPacer`            | shown when true                        |
| Stopped icon | `entry.stoppedHere`          | shown when true                        |

**State coloring (replaces hardcoded RGB):**
- **Synced** (`entry.submitted == true`): primary text uses `Theme.success`;
  pacer/stopped icons use their green variants (or tinted SF Symbols in green).
- **Unsynced, found:** `Theme.label`.
- **Unsynced, bib not found:** name in `Theme.destructive`, bold — preserves the
  current "Bib not found" emphasis.
- Pacer/stopped icons keep their existing asset images for the non-synced state, or
  are migrated to tinted SF Symbols; either is acceptable as long as visibility
  toggling matches today (`!withPacer` / `!stoppedHere` hidden).

Tapping a row keeps today's behavior exactly: syncing-entry guard alert, the
"already synced → create replacement?" flow, and the normal edit path — all via the
unchanged `didSelectRowAt` logic.

---

## 4. Sync feedback (inline bar + toast)

Chosen over the full-screen overlay. The separate `loadingView` / progress-bar /
checkmark / "Return to Live Entry" overlay is **retired**.

On **Sync** tap (`onSubmit`, unchanged data path):
1. Sync button enters a syncing state: title → "Syncing…", disabled, and a slim
   progress indicator reflects `syncManager(_:progress:)`. (Either a thin
   `UIProgressView` under the button or an inline spinner in the button — a
   progress bar is preferred since progress is reported.)
2. Cells recolor to `Theme.success` as entries sync (already driven by `loadData()`
   on finish).
3. On completion, `OSTToast` shows the success/failure message (the existing
   `AutoSyncController.showToastOnCompletion` path). On error, the existing
   `ostPresentAlert` "Unable to sync" alerts are preserved (single- and
   alternate-server messages).
4. Button returns to "Sync N Times" / disabled "All Synced".

No full-screen takeover; the user stays on the list. `onReturnToLiveEntry` and its
outlets are removed along with the overlay (live entry remains reachable via the
menu).

**Sync button label:** reflects the unsynced count (entries matching the existing
`submitted == NIL && bibNumber != "-1"` predicate). Zero → disabled "All Synced".

---

## 5. Export (header button)

Export stays a screen-local action (it exports *this screen's* entries to a local
CSV; it is not global navigation, so it does **not** belong in the right-menu
`SETTINGS` card). It lives as the header Export button and calls the **unchanged**
`onExport` → "local device only" confirmation alert → `exportCSV` →
`UIActivityViewController` (with the existing iPad popover anchoring).

---

## 6. Error handling

- Sync errors: unchanged `ostPresentAlert` flows for primary and
  primary+alternate-server failures.
- Empty states: unchanged "No times have been entered." / "All times have been
  synced." alerts on Sync/Export when nothing qualifies.
- Edit conflicts: unchanged "Unable to edit time" / "already synced → replacement?"
  alerts.

---

## 7. Testing

Follows the project convention: pure logic + view-config via XCTest test seams;
UIKit window/layout glue verified by green build + manual check.

- **ReviewEntryCell** unit tests (new): configure with a synced entry → asserts
  success-colored labels and visible green pacer/stopped icons; unsynced found →
  `Theme.label`; unsynced "Bib not found" → `Theme.destructive` + bold; bib `-1` →
  empty bib label; In/Out capitalization. Assert via public test-seam properties
  (mirror `OST TrackerTests/Swift/…` patterns).
- **Sort persistence:** assert selecting a sort option writes
  `reviewScreenPicklistValue` and that `loadData()` sorts by the mapped key/order
  (reuse existing sort mapping; extract to a pure function if it eases testing).
- **Sync button label:** pure helper mapping unsynced count → title
  ("Sync N Times" / "All Synced", enabled/disabled) is unit-tested.
- **Manual checklist (hand to user):** header badge over menu; Export sheet; sort
  bottom-sheet updates list; cells recolor green after sync; inline progress +
  success toast; error alert on forced failure; bottom bar clears the home
  indicator on a notched device and last rows scroll clear; edit/replacement flows.

Build/test command (substitute an available sim from `xcrun simctl list devices
available`):
`xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`

---

## 8. Out of scope

- The right-menu rewrite (separate plan).
- Changing sync/export/edit business logic or the AutoSync engine.
- Any backend/API changes.
