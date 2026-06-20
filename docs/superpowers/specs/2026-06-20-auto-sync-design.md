# Auto Sync Mode — Design (Swift rewrite)

**Date:** 2026-06-20
**App:** OST Remote (`ost-remote-complete`, Swift + UIKit, iOS 12 floor)
**Status:** Approved design, ready for implementation planning
**Supersedes:** `../../../OST-Remote/docs/superpowers/specs/2026-06-14-auto-sync-design.md`
(written against the older Objective-C app, before this rewrite existed)

## Summary

Add an opt-in **Auto Sync** mode. When enabled, the app automatically uploads
recorded times to opensplittime.org while the user stays on the entry screen —
never requiring a trip to the Review & Sync pane to push data. Sync status is
shown on the entry screen via a colored status strip under the header.

Today, syncing is manual: the user records times, opens **Review & Sync**, and
taps **Submit**, which runs login → submit-in-batches → marks each
`EntryModel.submitted = YES`. Auto Sync automates that same flow on the user's
behalf, and both paths share one implementation.

## Goals

- Sync pending entries automatically while Auto Sync is ON, without leaving the
  entry screen.
- Make sync status visible at a glance on the entry screen.
- Never strand an unsent entry; retry until it lands.
- Keep the manual Review & Sync pane working as a fallback.
- A single sync implementation shared by the auto path and the manual button (DRY).

## Non-Goals

- True iOS background syncing. Sync runs only while the app is foreground/active.
- Automatic detection of connection quality/speed. Enabling the toggle is the
  user's judgment that their connection is good enough.
- Changing the on-wire submit format or the server API. The existing
  `LiveTimeEntry` payload (and its golden tests) stay byte-compatible.

## What this codebase already has (and how it differs from the old spec)

The 2026-06-14 spec assumed an Objective-C app and told us to **build** a new
`OSTSyncManager` singleton. That no longer fits — this rewrite is further along:

- **`OSTSyncManager` (Obj-C) already exists** and is the *real* submit engine
  used by the manual Review pane today: login → `submitEntries` in batches of
  300 → mark `submitted` → save → completion toast, with primary/alternate
  server fallback chosen by login outcome. It notifies screens through a
  **delegate list** (`OSTSyncManagerDelegate`: start / progress / finish /
  finish-with-errors) and exposes `isSyncing`, `syncingEntries`,
  `isSyncingEntry:`, `showToastOnCompletion`.
- **`SyncService` (Swift) already exists** but is wired only to tests. It is a
  clean, injectable reimplementation of the submit flow (login + batched submit,
  primary/alternate by login outcome) and is the rewrite's intended engine.
- **`OSTBaseViewController`** registers every screen as an `OSTSyncManager`
  delegate and renders a pending-count **badge** on the menu button.
- **`OSTReachability.shared`** wraps `NWPathMonitor` but exposes only
  `isReachable` / `start()` — no change callback yet.
- **`AppDelegate`** lifecycle hooks (`applicationDidBecomeActive`,
  `applicationDidEnterBackground`) are empty stubs. The entry-screen VC is a
  persisted single instance; the Review pane is recreated each time.
- Entry saves go through Core Data `mr_saveOnlySelfAndWait` on the default
  context, which posts the standard `NSManagedObjectContextDidSave`.

## Key Decisions

| Decision | Choice |
|----------|--------|
| Engine | Build on the Swift **`SyncService`**; retire the legacy submit logic. |
| Brain | One Swift singleton, **`AutoSyncController`**, absorbs `OSTSyncManager`'s role **and** the auto-sync orchestration. `OSTSyncManager.h/.m` is deleted. |
| Activation | A toggle, **default OFF** on first run, remembered across launches. Manual Review & Sync remains the fallback. |
| Toggle location | **Right menu only** (UI-scope choice B). No switch on the entry screen. |
| Status placement | A **full-width status strip under the header** on the entry screen (placement 1); lower content shifts down when ON, collapses when OFF. |
| Status states | `Synced`, `Pending`, `Syncing`, `Failed`, `Offline` (strip hidden when Auto Sync is OFF). |
| Strip tap | Forces an immediate retry when `Failed` or `Offline`; inert otherwise. |
| Trigger | **Debounced after each entry**, plus **periodic retry while pending**, plus **sync on connectivity regained**. |
| Styling | Modern/iOS-standard look for the strip and the menu switch. |

## Architecture

### One brain: `AutoSyncController` (new, Swift, `@objc`)

A singleton created lazily by `AppDelegate`, mirroring the `getNetworkManager`
pattern. It holds no UI references. It **replaces `OSTSyncManager`** entirely,
absorbing both responsibilities:

**From the old `OSTSyncManager` (so the UI keeps working):**
- `isSyncing`, `syncingEntries`, `isSyncingEntry:`, progress reporting,
  completion toast (`showToastOnCompletion`), and the observer dispatch.
- The existing observer protocol's **shape is preserved** (start / progress /
  finish / finish-with-errors) so the three consumers change minimally:
  `OSTBaseViewController`, `OSTReviewSubmitViewController`,
  `OSTRightMenuViewController` re-point from `OSTSyncManager.shared()` to
  `AutoSyncController.shared`.

**New auto-sync orchestration:**
- Persisted `autoSyncEnabled` (BOOL) in `NSUserDefaults`; first-run default OFF.
  Turning ON triggers a sync if entries are pending; turning OFF stops timers and
  hides the strip.
- The status state machine, debounce/periodic/backoff timers, reachability
  observation, and foreground/background handling described below.

**Why one class instead of a controller layered over a kept `OSTSyncManager`:**
two notification systems for one concept invites drift. Collapsing them is the
DRY end-state the rewrite targets, and there are only three consumers to update.

### The single sync path — `syncNow`

Both the auto path and the manual Submit button call **one** method.

1. Gather pending entries:
   `combinedCourseId == currentCourse.eventId && submitted == NIL && bibNumber != "-1"`,
   in a stable order (this matches today's manual submit filter).
2. Map each `EntryModel` to a **`LiveTimeEntry`** in that same order. This
   `EntryModel → LiveTimeEntry` mapper is **new** (none exists yet);
   `LiveTimeEntry` and its golden payload are left untouched.
3. Run `SyncService.sync(liveEntries)` with closures wired to the real network:
   - `login` → wraps the existing `autoLogin` (primary server on success,
     alternate on failure — preserving today's behavior exactly).
   - `submitBatch` → POSTs the batch and, **on each batch success, marks that
     batch's `EntryModel`s `submitted = YES` and saves Core Data**, so partial
     progress persists across a mid-run failure. `SyncService` batches
     deterministically (`prefix(300)`, in order), so a running offset cursor in
     the `submitBatch` closure pairs each `LiveTimeEntry` batch back to its source
     `EntryModel`s without changing `LiveTimeEntry`.
4. On overall success: update `lastSyncDate`, transition to `Synced`, reset
   backoff. A single **in-flight guard** prevents overlapping attempts.

`OSTReviewSubmitViewController.onSubmit` is rewired to call this shared
`syncNow`, so there is exactly one sync implementation.

### Published status

An immutable status value, exposed as a `currentStatus` property and broadcast
on every change via an `OSTSyncStatusChanged` notification:

- `state`: `Synced | Pending | Syncing | Failed | Offline`
  (when `autoSyncEnabled == NO`, the strip is hidden — a "disabled" display state).
- `pendingCount`: count using the **same predicate as the sync path** (excludes
  `bibNumber == "-1"`), so "N to sync" is truthful.
- `lastSyncDate`: timestamp of the last successful sync (drives "All synced ·
  2:07 PM").

A freshly-shown screen renders immediately from `currentStatus` (pull), then
stays current via the notification (push).

### Triggers

1. **Debounced after entry.** Observe `NSManagedObjectContextDidSave`. A save
   that leaves pending entries (re)starts a short **~3s debounce**, then syncs.
   Observing Core Data saves keeps the controller decoupled from the entry
   screen. **Guard:** the controller's own submitted-flag save must not
   re-trigger the loop (suppress observation during its own save block / ignore
   saves that only flip `submitted`).
2. **Periodic retry while pending.** A repeating timer runs **only while
   `pendingCount > 0`**, idling when caught up, so nothing is stranded.
3. **Connectivity regained.** Extend `OSTReachability` with a change
   notification (today it only exposes `isReachable`). On transition to
   reachable with entries pending, sync immediately.
4. **Toggle ON** → sync now if pending. **Toggle OFF** → stop timers, hide strip.

### Error handling & backoff

- **Failure** → `Failed`. The retry timer backs off through a capped schedule:
  **5s → 15s → 30s → 60s (cap 60s)**. Any success resets the backoff.
- **Not reachable** → `Offline`. We do not hammer a dead link. A strip tap, or
  regained connectivity, forces a retry.
- **Login failure** (bad/expired credentials) surfaces as `Failed`, like any
  other failure.

### Foreground / background

Timers and syncing run while the app is **active**. On
`applicationDidEnterBackground` the controller pauses; on
`applicationDidBecomeActive` it resumes and syncs if anything is pending. No iOS
background execution (out of scope). Both lifecycle hooks are empty stubs today.

## UI Integration

### Entry screen — `OSTRunnerTrackerViewController` (+ xib)

- **Status strip under the header** (placement 1). When Auto Sync is ON, lower
  content shifts down by the strip height; when OFF, the strip is hidden and the
  space collapses. Colored by `state`, modern/iOS-standard styling:
  - `Synced` — green — "Auto Sync · All synced · 2:07 PM"
  - `Pending` — blue — "Auto Sync · N to sync…"
  - `Syncing` — yellow — "Auto Sync · Syncing N…"
  - `Failed` — red — "Sync failed · retrying soon · N pending"
  - `Offline` — grey — "Offline · N waiting to sync"
- **Tap the strip → force retry** only when `Failed` or `Offline`; otherwise the
  tap is inert (gesture guarded by current state).
- Subscribes to `OSTSyncStatusChanged` in `viewWillAppear`, renders from
  `currentStatus` on appear, unsubscribes in `viewWillDisappear`.
- The vertical shift reuses the same machinery the screen already applies for the
  safe-area fix in `viewDidLayoutSubviews`.
- **No Auto Sync switch on this screen** (the toggle lives in the menu).
- The existing pending-count **badge** on the menu button is retained, unchanged.

### Right menu — `OSTRightMenuViewController` (+ xib)

- An **Auto Sync switch** added alongside Cross Check / Review & Sync /
  Utilities / Logout, bound to `AutoSyncController.autoSyncEnabled`. Flipping it
  updates the persisted setting, which posts the status notification so the strip
  appears/disappears.

### Review & Sync pane — `OSTReviewSubmitViewController`

- Remains the manual fallback.
- Its **Submit button calls the shared `syncNow`**, removing any duplicate submit
  flow. Keeps its existing spinner / progress bar / alerts via the preserved
  observer protocol.

## Components Touched / Added

| Component | Change |
|-----------|--------|
| `AutoSyncController` (Swift) | **New.** Absorbs `OSTSyncManager`'s role + auto-sync brain: state machine, timers, backoff, reachability, `syncNow`, persisted `autoSyncEnabled`, status notification, observer dispatch, toast. |
| `EntryModel → LiveTimeEntry` mapper (Swift) | **New.** Stable-order conversion feeding `SyncService`; round-trips to the golden payload. |
| `SyncService` (Swift) | Reused unchanged as the submit engine. |
| `OSTSyncManager` (.h/.m) | **Deleted.** Consumers re-point to `AutoSyncController`. |
| `OSTReachability` (Swift) | Add a connectivity-change notification (today only `isReachable`). |
| `AppDelegate` (.m) | Lazily own `AutoSyncController`; forward foreground/background lifecycle to it. |
| `OSTRunnerTrackerViewController` (.swift/.xib) | Status strip under the header, shift-down, tap-to-retry, status subscription. |
| `OSTRightMenuViewController` (.m/.xib) | Auto Sync switch; re-point to `AutoSyncController`. |
| `OSTReviewSubmitViewController` (.swift) | Submit calls `syncNow`; re-point to `AutoSyncController`. |
| `OSTBaseViewController` (.h/.m) | Re-point delegate registration to `AutoSyncController`. |

## Testing (`OST TrackerTests`, Swift)

`SyncService`'s injected `login` / `submitBatch` already make the network
fake-able. `AutoSyncController` is tested with a faked clock/timers and
reachability for determinism.

Cases:
- Debounce coalesces multiple rapid entries into one sync.
- Happy path: `Pending → Syncing → Synced`; `lastSyncDate` set.
- Failure path: `→ Failed`, backoff escalates (5/15/30/60s), resets on success.
- `→ Offline` when reachability reports unreachable; retry on regain / strip tap.
- In-flight guard prevents overlapping attempts; the controller's own save does
  not re-trigger the debounce.
- `pendingCount` recomputation (excludes `bibNumber == "-1"`).
- `autoSyncEnabled` persistence and immediate-sync-on-enable behavior.
- `EntryModel → LiveTimeEntry` mapper round-trips to the golden payload; per-batch
  `submitted` marking after a partial (mid-run) failure persists the synced
  batches and leaves the rest pending.

## Settled Defaults

Fixed unless implementation surfaces a reason to revisit:

- Debounce window: **~3s**.
- Backoff schedule: **5s → 15s → 30s → 60s**, cap 60s.
- Batch size: **300** (inherited from `SyncService`).
