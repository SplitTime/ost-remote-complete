# Auto Sync: hold the on-screen entry until confirmed

**Date:** 2026-06-20
**Status:** Approved (approve-to-completion)

## Problem

On the bib-entry screen (`OSTRunnerTrackerViewController`), recording a runner shows a
green **runner badge** ("TAP TO EDIT") for the just-recorded entry (`lastEntry`). The
badge is the user's chance to spot a mistake and tap into the edit/delete sheet.

Auto Sync (`AutoSyncEngine` → `AutoSyncController`) debounces a Core Data save by 3
seconds, then submits **all** pending entries (`submitted == NIL`) for the event —
including the one still displayed and editable on screen. Once an entry is marked
`submitted == true`, later local edits/deletes no longer re-sync, so a correction made
right after recording is silently lost.

There is also no explicit way to clear the badge; it only goes away when the user types a
new bib or records another runner.

## Goal

1. Auto Sync must not submit the entry currently displayed (held) on the entry screen.
2. Give the user an explicit **Confirm** action on the badge that commits the entry (clears
   the badge and releases it to Auto Sync).

## Decisions (from brainstorming)

- **Hold scope:** Hold *only* the single entry currently displayed. All other pending
  entries continue to sync normally. Only one entry is ever held at a time (only one badge
  shows).
- **Release model — an entry is released (becomes eligible for Auto Sync) when:**
  - the user taps **Confirm**, or
  - the user records the next runner, or
  - the user types a new bib (badge replaced/cleared), or
  - the entry screen disappears, or the app enters background (safety: never leave a
    recorded time stuck unsynced).
- **Manual sync ignores the hold.** An explicit *Sync Now* / Review-&-Sync submit drains
  everything pending, including the held entry. Explicit user action overrides the hold.
- **Dismiss affordance:** a **Confirm** button on the badge (not an ✕). Confirm both
  commits the held entry to Auto Sync and resets the screen for the next bib.

## Architecture

### `AutoSyncController` (production wiring)

Add a single piece of state: the held entry's permanent `NSManagedObjectID`.

```
private var heldEntryID: NSManagedObjectID?

@objc func holdEntry(_ entry: NSManagedObject)   // sets heldEntryID; refreshes status only
@objc func releaseHeldEntry()                    // clears heldEntryID; pokes a sync
private func clearHeldEntry()                     // clears heldEntryID, no poke (background)
```

- `holdEntry` records `entry.objectID` (permanent after save) and calls `engine.refresh()`
  so the status strip/count drops the held entry immediately. It does **not** trigger a sync.
- `releaseHeldEntry` clears the id and calls `engine.noteEntriesChanged()` so the
  just-released entry syncs on the normal 3s debounce. No-op (no poke) if nothing was held.

**Eligibility filter** — a pure helper, unit-tested:

```
func entriesEligibleForAutoSync(_ all: [NSManagedObject],
                                heldEntryID: NSManagedObjectID?) -> [NSManagedObject]
```
Returns `all` minus the held entry.

**Fetch split:**
- Auto path (`pendingCount` closure and `performAutoSync`) uses
  `fetchPending(excludingHeld: true)` → filtered through `entriesEligibleForAutoSync`.
- Manual path (`syncNow`) uses `fetchPending()` (unfiltered). `syncEntries(_:)` is already
  explicit and unchanged.

**Background:** `applicationDidEnterBackground` calls `clearHeldEntry()` before
`engine.enterBackground()`, so the next foreground resume syncs the formerly-held entry.

Consequence: when the *only* pending entry is the held one, the auto pending count is 0, so
the engine rests in `.synced` (no retry churn). The on-screen badge + its Confirm button are
what signal the entry is not yet committed. The red menu count badge
(`OSTBaseViewController.updateSyncBadge`) is left counting all `submitted == NIL` entries
(it honestly reflects "unsynced"); it clears once the held entry is confirmed and synced.

### `AutoSyncEngine`

Add a public `func refresh()` that simply re-publishes `currentStatus` (so a hold change
updates observers without scheduling a sync). The engine itself is unchanged otherwise — it
already reads the (now hold-aware) `pendingCount` closure.

### `OSTRunnerTrackerViewController` (entry screen)

- **On record** (`onEntryButton`): after `saveContext()` and `lastEntry = entry`, call
  `AutoSyncController.shared.holdEntry(entry)`. Recording the *next* runner overwrites the
  held id, so the previous entry becomes eligible and the new save's debounce syncs it.
- **On new bib** (`updateBibInfo`, which already sets `lastEntry = nil`): call
  `AutoSyncController.shared.releaseHeldEntry()` (idempotent; only pokes if something was held).
- **On disappear** (`viewWillDisappear`): call `releaseHeldEntry()`.
- **Confirm button:** add `btnConfirm`, a compact filled pill overlaid in the top-right
  corner of the fixed-height result slot, visible only while the runner badge is shown
  (toggled alongside `runnerBadge.isHidden`). Tapping it resets the display (clear badge,
  reset toggles + bib field, back to "Enter Bib Number") and calls `releaseHeldEntry()`.
  Placing it as an overlay keeps the slot's constant height, so toggle/entry buttons never
  shift (the file's existing no-reflow invariant).
- **Edit sheet:** `entryHasBeenDeletedBlock` also calls `releaseHeldEntry()` (the held
  object is gone). Editing (`entryHasBeenUpdatedBlock`) keeps the entry held — it's still
  displayed — until the user confirms or moves on.

## Testing

- Unit-test the pure `entriesEligibleForAutoSync` filter with two `EntryModel`s in an
  in-memory context: held excluded, others kept, `nil` held returns all.
- Existing `AutoSyncEngineTests` continue to cover engine behavior (the engine is unchanged
  except for the additive `refresh()`).

## Out of scope

- No new `AutoSyncState` case for "held." No changes to the submit payload, backoff, or the
  manual Review-&-Sync flow beyond it ignoring the hold (which it already does, since it
  fetches unfiltered).
