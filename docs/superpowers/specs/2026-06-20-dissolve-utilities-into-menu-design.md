# Dissolve Utilities into the Right Menu

**Date:** 2026-06-20
**Branch:** swiftui-rewrite
**Status:** Approved (design)

## Goal

Remove the standalone Utilities screen entirely and fold its actions into the
right-side navigation drawer (`OSTRightMenuViewController`). The drawer already
hosts the Auto Sync toggle, so settings-in-the-menu is an established pattern
here; Utilities is the only menu row that opens a screen just to present more
buttons. Dissolving it removes a navigation hop, consolidates every setting in
one place, and deletes a whole view controller + XIB.

## Background

**Current Utilities screen** (`OSTUtilitiesViewController.swift` + `.xib`):
title "Utilities OST", a menu badge, and five actions — Refresh Data, Change
Station, Appearance, About, Logout — plus a full-screen overlay (logo + progress
bar → "Success!/Failure!" panel with "Return to Live Entry" + "Retry").

**Current right menu** (`OSTRightMenuViewController.swift`): a close button, a
brand row (logo + "OST Remote"), a single card of six `MenuRow`s (Live Entry,
Review / Sync, Cross Check, Live Reads, Race Status, Utilities), and an Auto Sync
switch pinned to the bottom. Fully programmatic, `Theme`-driven, iOS 12-safe.

`MenuRow` (`Swift/DesignSystem/MenuRow.swift`) is a `UIControl` with a title, an
optional red count badge, an optional inline spinner (`showsSpinner`), and a
trailing chevron.

## Decisions (from brainstorming)

- **Dissolve** the Utilities screen into the menu (vs. keeping a separate
  "Settings" screen).
- **Rename** "Refresh Data" → **"Refresh Roster"** (clearer about what it pulls).
- **Refresh Roster feedback:** inline spinner in the row, then a toast on
  success / an alert with Retry on failure. No full-screen takeover, no "Return
  to Live Entry".
- **Appearance:** opens a `BottomSheetPicker` (System / Light / Dark) instead of
  a `UIAlertController` action sheet; the row shows the current mode as trailing
  detail text.
- **Grouping:** the drawer is organized into a NAVIGATION section and a SETTINGS
  section, with Logout as a separate destructive action at the bottom.

## Design

### Drawer layout

```
Close ✕
🔷 OST Remote

NAVIGATION
┌────────────────────────────┐
│ Live Entry              ›  │
│ Review / Sync       ②   ›  │   ← unsynced badge + sync spinner (unchanged)
│ Cross Check             ›  │
│ Live Reads              ›  │
│ Race Status             ›  │
└────────────────────────────┘

SETTINGS
┌────────────────────────────┐
│ Refresh Roster      ◌      │   ← inline spinner while refreshing, no chevron
│ Change Station          ›  │
│ Appearance      System  ›  │   ← trailing detail = current mode
│ About                   ›  │
└────────────────────────────┘
   Auto Sync           [ ●]      ← existing toggle, repositioned under Settings

        Log Out  (red)            ← destructive UIButton, centered
```

- Two `Theme.fieldFill` rounded cards (reuse the existing card + hairline
  `makeSeparator()` construction), one per section.
- Light section headers ("NAVIGATION", "SETTINGS") using `Theme.Font.caption` /
  `Theme.secondaryLabel`. They clarify nav-vs-settings; keep them subtle.
- **Scroll:** wrap the whole content stack in a `UIScrollView` so the longer list
  never clips on the smallest phones. On the iPad-mini floor everything fits
  without scrolling, but the scroll view is harmless there.
- Auto Sync moves from a bottom-pinned row to a row directly beneath the Settings
  card (label + `UISwitch`, unchanged behavior).
- **Log Out** is a separate centered destructive `UIButton` (`Theme.destructive`
  title, `.system` style) at the very bottom of the scroll content — visually set
  apart from the tappable rows, matching the logout button in Event Selection.

### `MenuRow` enhancements (DRY — extend, don't duplicate)

Add two small, optional capabilities to the existing component:

- **`detailText: String?`** — a trailing secondary label (between title and
  chevron), `Theme.secondaryLabel`. Used by Appearance to show the current mode.
- **`showsChevron: Bool` (default `true`)** — Refresh Roster sets `false` since
  it performs work in place rather than navigating.

No new `SettingsRow`/`SettingsList` component is needed — `MenuRow` covers every
row, so this is *less* code than the separate-screen plan.

### Actions

All action logic is ported from the current `OSTUtilitiesViewController` into
`OSTRightMenuViewController`; behavior is identical except where noted.

- **Refresh Roster** — `row.showsSpinner = true`, disable the row, call
  `OSTBackend.getEventsDetails(currentCourse.eventId)`; on the response, port the
  existing reconcile logic verbatim (`EffortModel.mr_reconcile`, `dataEntryGroups`,
  `monitorPacers`, `eventIdsAndSplits`, `eventShortNames`, then
  `processPendingChanges` + `mr_saveOnlySelfAndWait`). Stop the spinner; on
  success show a toast "Roster updated."; on failure show a `UIAlertController`
  with **Retry** / **Cancel**. The drawer stays open (the toast renders over the
  window).
- **Change Station** — close the drawer, then present
  `OSTEventSelectionViewController` with `changeStation = true` from the center
  view controller.
- **Appearance** — open `BottomSheetPicker` with ["System", "Light", "Dark"],
  selected = current `AppearanceController.shared.mode`; on choice set the mode and
  update the row's `detailText`.
- **About** — close the drawer, `AppDelegate.getInstance()?.showAbout()` (the
  About screen itself is out of scope and unchanged).
- **Log Out** — port the two-path flow verbatim: a "Checking connection…" alert
  with a spinner → `OSTBackend.verifyConnection`; on success present the standard
  confirm dialog, on failure present the "Can't reach OpenSplitTime" override
  dialog; `performLogout()` toggles the drawer and calls `AppDelegate.logout()`.

### `OSTToast` generalization (DRY)

`OSTToast.show(success:)` currently hardcodes "Times synced successfully." Add
`show(message:success:)` carrying a custom message; make the existing
`show(success:)` delegate to it with its current strings. Refresh Roster calls
`show(message: "Roster updated.", success: true)`.

### Removal / cleanup

- Delete `OSTUtilitiesViewController.swift` and `OSTUtilitiesViewController.xib`
  and their project references.
- Remove the `utilitiesRow` and its `onUtilities` handler from the menu.
- Remove `AppDelegate.showUtilities` (verify no remaining references first).

## Scope

**In scope:** the right menu, dissolving Utilities, the two `MenuRow`
enhancements, the `OSTToast` generalization, and deleting the Utilities VC + XIB.

**Out of scope:** the About screen, the Live Entry / Review / Cross Check / Live
Reads / Race Status destinations, the Auto Sync engine, and any backend changes.

## Constraints

- iOS 12-safe throughout (`.gray` spinners; no APIs gated above iOS 12).
- All colors/fonts/metrics via `Theme`; never hardcode.
- Preserve the base VC's unsynced-count badge + AutoSync observer wiring on the
  Review / Sync row.

## Verification (hand to user)

Build `OST Remote` green, then in the app: open the drawer → confirm the two
sections render and scroll on a phone; tap **Refresh Roster** (inline spinner →
"Roster updated." toast; force an error → Retry alert); **Change Station** opens
event selection in change-station mode; **Appearance** opens the bottom-sheet and
the detail text updates; **About** navigates; **Auto Sync** toggle still works;
**Log Out** runs the connection-check → confirm/override flow. Confirm the old
Utilities row/screen is gone.
