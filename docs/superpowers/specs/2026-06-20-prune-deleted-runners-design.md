# Prune deleted runners from the cross-check roster

**Date:** 2026-06-20
**Status:** Approved — ready for implementation plan

## Problem

On the cross-check screen, a runner who was removed from the event roster on the
server keeps showing as "Expected" forever. Pressing **Refresh Data** does not
clear them.

## Root cause

The roster import is purely additive. Both import call sites —
`OSTUtilitiesViewController.onRefreshData` (Refresh Data) and
`OSTEventSelectionViewController` (event selection) — loop over the `efforts`
objects in the response and call `EffortModel.mr_import(from:)`, which *upserts*
by `effortId` (`MagicalRecordShim.swift`). Nothing ever deletes local efforts
that are no longer in the response. The only place efforts are cleared today is
`MR_truncateAll` at logout (`AppDelegate.m`).

The cross-check screen builds its list from all local efforts
(`EffortModel.mr_findAllSorted`), so a removed runner lingers in Core Data with
no entry and `expected()` returns `YES` — hence the permanent "Expected".

## Out of scope: DNS

"Did not start" runners are already handled correctly and need no change. The
server's `not_expected` endpoint (`OSTBackend.fetchNotExpected`) returns DNS bibs,
and the cross-check screen consumes that list on every open
(`OSTCrossCheckViewController.bulkNotExpected`), flipping them to "Not Expected".
Verified against the live backend. This fix does not touch the DNS path.

## Design

Add one shared, self-describing helper that replaces the duplicated import loop
at both call sites:

```swift
extension EffortModel {
    /// Upserts the efforts in `included` and deletes any local effort that is no
    /// longer present on the server (a removed roster entry). Skips pruning when
    /// the response carries no efforts, to avoid wiping the roster on a partial
    /// or malformed 200.
    static func reconcileRoster(fromIncluded included: [[String: Any]])
}
```

Behavior:

1. Filter `included` to objects whose `type == "efforts"`.
2. If that filtered list is empty, return without pruning (safety guard).
3. Build `serverIds: Set<String>` from each effort's `id`.
4. Upsert each effort via the existing `EffortModel.mr_import(from:)`
   (behavior unchanged).
5. Prune: fetch all local `EffortModel`; delete any whose `effortId` is not in
   `serverIds`.
6. Save once: `processPendingChanges()` then `mr_saveOnlySelfAndWait()` on the
   default context.

### Call sites

Replace the inline `for dataObject in included where … efforts { EffortModel.mr_import(from:) }`
loop (plus its trailing save, in the Refresh Data case) with a single call to
`EffortModel.reconcileRoster(fromIncluded: included)` in:

- `OSTUtilitiesViewController.onRefreshData`
- `OSTEventSelectionViewController` (event-details completion)

The surrounding code that imports `events` objects and sets `CurrentCourse`
fields is unchanged.

### Why it fixes the bug

After a refresh, efforts removed on the server are deleted locally, so they no
longer appear on the cross-check screen in any filter.

## Decisions and trade-offs

- **Safety guard over completeness.** Skipping prune on an empty efforts list
  means a roster legitimately emptied to zero would not be reflected. That case
  is negligible in practice; protecting against a partial/malformed response that
  would otherwise erase the whole roster is worth it. Callers already return
  early on `error != nil`, so prune runs only on an otherwise-successful fetch.
- **Leave entries alone.** Orphaned `EntryModel` and `CrossCheckEntriesModel`
  rows for a removed bib are not deleted. Recorded entries are user-submitted
  data; cross-check renders only from efforts, so orphans never display.
- **Shared helper, not truncate-and-reimport.** A diff-and-prune avoids briefly
  emptying the store and keeps the change DRY across both call sites.

## Testing

Unit-test `reconcileRoster(fromIncluded:)` against a fixture:

- Import a roster, then re-run with one effort removed from `included`; assert the
  removed effort is gone and all others survive.
- Re-run with an empty efforts list; assert the existing roster is left intact
  (safety guard).
- Re-run with an unchanged roster; assert no efforts are added or deleted.
