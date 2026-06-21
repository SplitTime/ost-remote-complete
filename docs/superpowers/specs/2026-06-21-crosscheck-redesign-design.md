# Cross Check Page — Redesign

Date: 2026-06-21
Branch: `crosscheck-redesign` → merges into `swiftui-rewrite`

## Purpose

The Cross Check screen is the aid-station reconciliation view: for the current
split, a volunteer checks which runners (bibs) have come through. The legacy
screen is a dense grid of loudly color-filled tiles (Expected = bright blue,
Recorded = green-on-white, Dropped Here = red-on-white, Not Expected =
dark-olive) with an `OSTCheckmarkView` filter footer and a bulk-select mode.

This redesign brings the page into the new design system (grouped background,
system fonts, `Theme` roles, restrained status color) and reshapes the layout
around the volunteer's **primary job: spotting who hasn't arrived yet** (the
Expected / "still out" runners).

The underlying data model and CoreData operations are unchanged — only the
presentation and interaction are rebuilt.

## Chosen design (Option C, simplified)

Validated via visual mockups. The screen is a single scrolling list:

1. **Nav header** — title "Cross Check", station name + total runner count, and
   the hamburger (right menu) button.
2. **In / Out segmented control** — shown only when the current split has paired
   in/in or out/out sub-splits (preserving the legacy `dataEntryGroups` logic).
   Switching reloads for the chosen sub-split.
3. **Still out — Expected** — the top section, a **fully expanded list** of rows
   (large bib + full name + chevron). The whole page scrolls as one list; the
   Expected list is never a nested scroll box and is never capped.
4. **Summary rows** — three compact rows below Expected: Recorded (green dot),
   Dropped here (red dot), Not expected (gray dot), each with a count and a
   chevron. Tapping drills into that group's list.
5. **Review →** button at the bottom (routes to the existing Review/Tracker).

Tapping any bib (an Expected row, or a row in a drill-in list) opens a **bottom
sheet** showing the bib + name, an **Expected / Not expected** segmented switch
(only for not-yet-recorded runners), and a **Review entries** action. This
per-bib sheet is the replacement for the removed bulk-select workflow.

Status color is restrained: a small colored **dot** or amber section accent, not
full-tile fills. "Still out / Expected" uses an **amber** accent (warning, draws
the eye) rather than the legacy bright blue, since the job is to notice missing
runners; blue stays reserved for the design system's neutral tint/links. This
requires adding a **`Theme.warning`** role (light/dark systemOrange) to
`Theme.swift` + `Palette`, since the design system has no warning color today.

## Architecture / components

All new Swift, iOS 12 compatible (completion handlers, no async/await), `Theme` +
shared design-system components, **programmatic (no storyboard/XIB)** — matching
the rebuilt Review and Race Status screens.

### Pure presentation — `CrossCheckPresentation.swift` (new, no UIKit/CoreData)

Mirrors `ReviewPresentation`. Maps efforts → display values + semantic color
roles so all "what status is this bib / which section does it belong to" logic is
unit-testable in isolation.

- `enum CrossCheckStatus { case expected, recorded, droppedHere, notExpected }`
- `struct CrossCheckRow: Equatable` — `bib: String`, `name: String`,
  `status: CrossCheckStatus`, optional `time: String?` (arrival time for
  recorded/dropped rows). The dot/accent color is derived from `status` by the
  view (see below) — the row does not carry a raw color.

The view maps `CrossCheckStatus` → `Theme` color for its dot/accent:
expected → `Theme.warning` (amber), recorded → `Theme.success`,
droppedHere → `Theme.destructive`, notExpected → `Theme.secondaryLabel`.
- A pure builder taking the resolved per-effort facts —
  `(bib, name, hasEntries, isStopped, isExpected, time)` — and returning a
  `CrossCheckBoard`:
  - `expected: [CrossCheckRow]`
  - `recorded: [CrossCheckRow]`
  - `droppedHere: [CrossCheckRow]`
  - `notExpected: [CrossCheckRow]`
  - convenience counts for the summary rows.

The view controller adapts `EffortModel` → those plain facts (reusing the
existing `entries(forSplitName:)`, `expected(withSplitName:)`, `stoppedHere`
logic) and hands them to the pure builder. No CoreData types cross into the pure
layer.

### Views — `CrossCheckListViews.swift` (new)

Programmatic `Theme`-based cells, same construction style as `ReviewListViews`:

- `ExpectedRow` (`UITableViewCell`) — large bib (`Theme.Font` bold), full name,
  trailing chevron.
- `SummaryRow` (`UITableViewCell`) — leading status dot, label, trailing count +
  chevron.
- A section header view for "STILL OUT — EXPECTED (n)".
- Drill-in lists reuse the **Review row style** (bib, name, time, status dot) —
  reuse `ReviewEntryCell` if it fits, otherwise a small shared `CrossCheckEntryRow`.

### Screen — `OSTCrossCheckViewController` (rebuilt)

Keeps its `@objc(OSTCrossCheckViewController)` name so existing navigation
(right-menu / AppDelegate routing) resolves unchanged. Rebuilt as a programmatic
`UITableView`-backed screen. The legacy storyboard and Obj-C view classes are
retired (see "What's removed").

Sections: `[Expected]` then a `[Summary]` section with the three summary rows.
`didSelectRow`:
- Expected row → present the bib action sheet.
- Summary row → push the drill-in list VC for that status.

### Drill-in — `CrossCheckGroupViewController` (new)

A small grouped-list VC initialized with a status + its `[CrossCheckRow]` and the
split name. Shows the rows (Review style), back button returns. Tapping a row
opens the same bib action sheet.

### Action sheet — bib status sheet

A bottom sheet (reuse `BottomSheetPicker` infrastructure from DesignSystem if it
fits; otherwise a small custom themed sheet) showing bib + name. For a
not-yet-recorded runner it shows the **Expected / Not expected** switch; for a
recorded/dropped runner it shows only **Review entries**. The toggle writes or
deletes a `CrossCheckEntriesModel` and saves context exactly as the legacy
`onClosePopup` did; **Review entries** calls the existing
`AppDelegate.showReview()` path.

## Data flow (underlying operations unchanged)

```
viewWillAppear
  → reloadData()                         [blocking spinner]
      → fetch efforts (EffortModel, sorted by bib)
      → fetchNotExpected(group, split)   [server-driven not-expected marking]
      → compute "should be here" efforts (checkIfEffortShouldBe / expected)
      → adapt efforts → plain facts → CrossCheckPresentation.build(...)
      → tableView.reload()
In/Out segmented change → clear effort vars → reloadData() for new sub-split
tap Expected row / drill-in row → bib action sheet
  → toggle Expected/Not-expected: write/delete CrossCheckEntriesModel, save, reload
  → Review entries: AppDelegate.showReview()
tap summary row → push CrossCheckGroupViewController(status)
Review button → existing review/tracker route
```

The automatic **server not-expected fetch** (`OSTBackend.fetchNotExpected` →
`bulkNotExpected(bibNumbers:)`) is preserved — only the *manual bulk* UI is
removed.

## What's removed

- **Bulk Select** entirely: the mode toggle, `bulkSelectMenuView`,
  `onBulkSelect`, `onBulkExpected`, `onBulkNotExpected`, and the
  `EffortModel.bulkSelected` UI usage.
- The **`OSTCheckmarkView` filter footer** and the five-filter mechanism
  (replaced by the Expected section + summary rows + drill-ins).
- Full-tile **color fills** (replaced by dots / amber accent).
- The **collection view**, `CrossCheck.storyboard`, and the Obj-C
  `OSTCrossCheckCell` / `OSTCrossCheckHeader` / `OSTCrossCheckFooter` classes.
- The already-dead **"In Aid"** status path (`setAsWithAid`, commented out in the
  legacy cell).

## Error handling

- Network/auth failure on `fetchNotExpected` is non-fatal: the screen still
  renders from local efforts (matching today's behavior — the fetch only adds
  not-expected marks).
- Blocking spinner via the existing shared spinner helper during `reloadData`.
- Empty Expected / group lists render an explicit empty state, not a crash.

## Testing

`CrossCheckPresentationTests` (XCTest, pure — no UI), mirroring
`ReviewPresentationTests`:

- **Section membership** — recorded / dropped-here / expected / not-expected
  efforts land in the correct board buckets.
- **Counts** — summary counts match bucket sizes.
- **Status mapping** — each effort's facts map to the expected
  `CrossCheckStatus` (expected / recorded / droppedHere / notExpected).
- **Edge cases** — empty-bib filtering (a nil bib that stringifies to "" is
  dropped; the effort-side "-1" filter was removed upstream as obsolete),
  a runner with entries but `stoppedHere` → dropped not recorded, a runner with
  no entries + explicit not-expected mark → notExpected.

A view-level smoke test (cell configuration) only if it adds value beyond the
pure tests.

## Out of scope (v1)

- Restoring any bulk operation (per-bib sheet only).
- Search / find-a-bib field (primary job is scanning Expected).
- Changes to the not-expected server contract.
- Offline behavior changes.
