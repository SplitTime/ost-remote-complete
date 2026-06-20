# Live Reads Pane — Design

**Date:** 2026-06-20
**Branch:** swiftui-rewrite (working branch: feature branch off it)
**Status:** Approved

## Summary

A new drawer screen in OST Remote that shows a live, auto-refreshing list of
raw times ("reads") landing at the station the device is logged in to. Primary
use case: watching reads flow in from an external timing system that submits to
OpenSplitTime, plus general "what's landing here" awareness across all sources.

Read-only monitor with two affordances: a **Go to Live Entry** button and a
**visible manual Refresh** button.

## Decisions (locked)

| Question | Decision |
|---|---|
| Placement | New full-screen item in the right-side drawer menu (mirrors Cross Check) |
| Scope | This station only (`CurrentCourse.splitName`), **all sources** |
| Refresh | Auto-poll every ~5s while visible; pauses off-screen / backgrounded |
| Row content | Bib + time + In/Out; Source; lap / pacer / stopped flags |
| Interaction | Read-only; row tap does nothing; header **Go to Live Entry** + **Refresh** buttons |
| State / dedup | Approach A: in-memory list, high-water-mark on `id`, merge new rows |
| Page size | `page[size]=50` (backend `MAX_PER_PAGE`) |
| Time display | `entered_time` as recorded; fall back to formatted `absolute_time` |

## Why polling, not the admin push connection

The admin "raw list" page updates via Hotwire **Turbo Streams over ActionCable**
(`turbo_stream_from @event_group`; `RawTime after_create_commit` broadcasts an
HTML turbo-stream fragment). Reusing that from the native app is a poor fit:
ActionCable subprotocol reimplementation, a Rails-**signed** stream name the
client can't mint, HTML (not JSON) payloads, and no `URLSessionWebSocketTask` on
the iOS 12 floor (would add a WebSocket dependency to a zero-dependency app).

Instead we poll the existing JSON API, which carries the same data as structured
JSON, uses the token auth the app already has, and adds zero dependencies.

## Backend contract

`GET /api/v1/event_groups/:event_group_id/raw_times`

Query used:
```
filter[split_name]=<station>&sort=-id&page[size]=50
```

- **Auth / access:** `index` authorizes via `EventGroupPolicy#index?` →
  `user.present?` (any logged-in user), and scopes the event group via
  `EventGroupPolicy::Scope#viewable` = `visible_or_delegated_to(user)`. A
  **Volunteer-level** steward is in `Organization.authorized_for(user)`
  (`stewardships.user_id = user`), so the event group is delegated to them even
  if concealed. **No admin account required** — any account that can already do
  live entry can read this feed.
- **No `since`/`>` operator:** filter is exact-match `where` only. We therefore
  sort `-id` and track a client-side high-water-mark; "new" = `id` above it.
- **Response:** JSON:API. `data` is an array of
  `{ id, type: "raw_times", attributes: { source, absolute_time, entered_time,
  bib_number, lap, split_name, sub_split_kind, data_status, stopped_here,
  with_pacer, remarks } }`.
- **Page cap:** server clamps `page[size]` to 50.

## Components

### `RawTime` (Swift value struct + pure parser)
Fields: `id: Int`, `bib: String`, `enteredTime: String?`, `absoluteTime: String?`,
`subSplitKind: String?` (In/Out), `source: String?`, `lap: Int?`,
`withPacer: Bool`, `stoppedHere: Bool`.

`static func parse(_ json: [String: Any]) -> [RawTime]` reads the JSON:API
`data[]` → `id` + `attributes`. Tolerates missing/null attributes. Pure, unit-tested.

### `LiveReadsMerge` (pure function)
```
merge(existing: [RawTime], incoming: [RawTime], highWaterMark: Int)
  -> (rows: [RawTime], newIds: [Int], highWaterMark: Int)
```
- `incoming` rows with `id > highWaterMark` and not already present are prepended
  (newest first).
- Returns the ids that are genuinely new (for highlight animation) and the
  advanced high-water-mark (`max` of all ids seen).
- Idempotent on overlap; stable ordering by descending `id`. Pure, unit-tested.

### `OSTBackend.fetchRawTimes(groupId:splitName:completion:)`
Builds the path above (percent-encoding handled by existing `getJSONObject`,
which already encodes `[`/`]`) and returns the parsed JSON dict via the existing
`request` path. Mirrors `fetchNotExpected`.

### `OSTLiveReadsViewController.swift` + `LiveReads.storyboard`
Center VC loaded from its own storyboard (mirrors how `OSTCrossCheckViewController`
loads from `CrossCheck.storyboard`). Owns:
- `var rows: [RawTime]`, `var highWaterMark: Int`, `var seenIds: Set<Int>`
- a 5s `Timer`
- a `UITableView` with a custom read cell

### Right-menu wiring
New "Live Reads" item in `OSTRightMenuViewController.m` (and the menu storyboard),
wired like `onCrossCheck:` — instantiate from `LiveReads.storyboard`, set
`AppDelegate.rightMenuVC.centerViewController`, toggle the drawer.

## Data flow / polling

1. **viewWillAppear:** reset `rows`, `highWaterMark = 0`, `seenIds = []`; fetch
   once (light blocking spinner only on this first load); start the 5s timer.
   With hwm 0, the first page populates without highlight.
2. **Timer tick (and Refresh button):** `fetchRawTimes` → `RawTime.parse` →
   `LiveReadsMerge.merge`. Apply returned rows; animate-highlight `newIds` (row
   background fades from a soft accent over ~1.5s); store advanced hwm. Update
   the "Updated HH:MM:SS" label + live dot. The Refresh button runs one immediate
   fetch and restarts the timer so it doesn't double-fire.
3. **viewWillDisappear / UIApplication didEnterBackground:** invalidate timer.
   **willEnterForeground (if still visible):** restart.
4. In-memory only; re-fetches fresh on next appearance.

## UI layout (modern iOS, iPad-mini-safe)

- **Header:** title `Live Reads — <station>`; live dot + `Updated 10:42:03`;
  visible labeled **Refresh** button; standard drawer/menu button.
- **Row:** large **bib** (left); **time** — `entered_time`, else formatted
  `absolute_time` — with **In/Out** chip (middle); **source** label + small
  badges `L<lap>` / pacer / stopped, shown only when set (right). New rows
  flash-highlight then settle.
- **Bottom bar:** prominent **Go to Live Entry** button → existing `showTracker`
  path (same as the menu `onSubmit:`).
- **Empty state:** centered "No reads yet at <station>".

## Error handling

- First load: existing light spinner.
- **Poll failures are non-blocking:** keep the last list, dim the live dot / show
  a small "couldn't refresh" hint, retry next tick. No modal on routine blips.
- `CurrentCourse` missing group/station → empty state, polling disabled.
- 401/auth handled consistently with the app's other `OSTBackend` calls.

## Testing

- **TDD (unit, `OST TrackerTests`):**
  - `RawTime.parse` — JSON:API shape, missing/null attributes, In/Out, flags,
    non-numeric guards.
  - `LiveReadsMerge.merge` — new-id detection, dedup/overlap, descending order,
    high-water-mark advance, empty existing / empty incoming.
- **Human-verified in simulator:** VC, timer lifecycle, storyboard, highlight
  animation, drawer item, Go-to-Live-Entry navigation (per batch-then-verify norm).

## Out of scope (YAGNI)

- CoreData persistence of reads (transient, server-authoritative).
- Whole-event-group or multi-source filtering toggles.
- Tap-to-act / review actions on a read (overlaps existing Review / Cross Check).
- True push (ActionCable). Revisit only via a future JSON-emitting backend channel.
