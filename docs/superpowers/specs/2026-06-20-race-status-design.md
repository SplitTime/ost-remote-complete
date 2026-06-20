# Race Status Page — Design

Date: 2026-06-20
Branch: `race-status` → merges into `swiftui-rewrite`

## Purpose

A read-only screen for viewing the state of the race as a whole, fed by the
OpenSplitTime spread endpoint. Two views on one page:

1. **By Runner** — search a single effort and see their times through every
   aid station / split so far.
2. **By Aid Station** — pick one split and see the whole field's progress
   through it.

Refresh is **manual**. The screen is **online-only** (live API, like the other
read screens); no offline cache.

## Data source

The app selects an **event group** (e.g. id 437, slug `test-lonesome-100`). The
spread endpoint is **per event**, keyed by event slug.

- `GET event_groups/{groupId}?include=events`
  → events in the group. Each event's `attributes` includes `slug`, `name`,
  `shortName`, `startTime`. Used to populate the event selector.
- `GET events/{eventSlug}/spread`
  → the spread for one event. Returns a JSON:API envelope:
  - `data.attributes`:
    - `name`, `courseName`, `organizationName`, `displayStyle`
    - `eventStartTime` (ISO8601 with offset, e.g. `2022-07-22T06:00:00.000-06:00`)
    - `splitHeaderData`: ordered array of stations, each:
      `{ title, split_name, distance (meters), extensions: [] | ["In","Out"], lap }`
  - `included`: array of `effortTimesRows`, each `attributes`:
    - `overallRank`, `genderRank`, `bibNumber`, `firstName`, `lastName`,
      `gender`, `age`, `stateCode`, `countryCode`, `flexibleGeolocation`
    - `stopped`, `dropped`, `finished` (booleans)
    - `absoluteTimes`: array **aligned by index** to `splitHeaderData`. Each
      element is an array of ISO8601 strings (or `null`) matching that station's
      sub-splits: 1 entry for a station with no extensions, 2 entries
      (In, Out) for an In/Out station. Missing times are `null`.

A captured fixture is committed at
`Verification/fixtures/spread-test-lonesome-100.json` for tests.

Auth token is per-call (existing `Authorization: bearer <token>`). The spread
endpoint requires authentication, same as the other reads.

## Architecture / components

All new Swift, iOS 12 compatible (completion handlers, no async/await), Theme +
shared design-system components, programmatic (no XIB) — matching the rebuilt
event-selection screen.

### Models — `SpreadModels.swift`
Codable structs decoding the envelope:
- `EventSpread` — `name`, `courseName`, `displayStyle`, `eventStartTime: Date`,
  `splitHeaders: [SplitHeader]`, `efforts: [EffortRow]`.
- `SplitHeader` — `title`, `splitName`, `distanceMeters`, `extensions: [String]`,
  `lap`. Convenience: `hasInOut` (extensions contains In/Out).
- `EffortRow` — ranks, `bibNumber`, `firstName`, `lastName`, `gender`, `age`,
  `flexibleGeolocation`, `stopped`, `dropped`, `finished`,
  `absoluteTimes: [[Date?]]`. Convenience: `fullName`.

A static `decode(from data: Data) -> EventSpread` walks `data` + `included`
(merging the JSON:API envelope into one value). ISO8601 dates parsed with a
fractional-seconds formatter that preserves the offset.

### Service — extend `OSTBackend`
Two read methods, layered on the existing `APIClient` + `ConnectivityChecker`
(autoLogin → request), main-queue completions:
- `eventsInGroup(groupId, completion: ([EventRef], Error?) -> Void)`
  where `EventRef = { slug, name, shortName }`.
- `spread(eventSlug, completion: (EventSpread?, Error?) -> Void)`.

These decode with the Codable models (not raw `[String:Any]`), so add an
`APIClient` path that returns `Data`/decodes a `Decodable` for JSON:API bodies,
or decode inside `OSTBackend` from the raw data. Keep one shared decode helper
(DRY).

### Screen — `RaceStatusViewController`
Programmatic themed VC. Layout top→bottom:
- Title row + **Refresh** button.
- **Event selector** (`DisclosureSelectField`) — hidden (and auto-selected)
  when the group has exactly one event.
- **Segmented control**: `By Runner | By Aid Station`.
- A **search/select field** whose meaning depends on mode:
  - By Runner: text field filtering by **bib or name**, showing a tappable list
    of matches.
  - By Aid Station: a split picker (course order).
- **Results table** (UITableView).

State machine: `loading` (spinner), `loaded`, `empty`, `error` (OSTAlert).
The fetched `EventSpread` is held in memory; mode toggle, runner selection, and
station selection re-render from memory with **no refetch**. **Refresh**
re-fetches the current event's spread. Changing the event refetches.

### View models (pure, testable)
- `RunnerProgressViewModel(effort, headers, eventStart)` → header summary
  (name, bib, ranks, status) + `[StationTimeRow]` where each row has the
  station title and, per sub-split, **elapsed-from-start (primary)** and
  **time-of-day (secondary)**. In/Out stations produce both In and Out lines;
  missing → "—".
- `StationFieldViewModel(splitIndex, efforts, headers, eventStart)` →
  count summary + `[FieldRow]` sorted by overall progress, each with bib, name,
  and a **status**:
  - `.finished` — `finished` true.
  - `.through(time)` — has an In time at this split (and not finished).
  - `.dropped(atStation)` — `dropped` true; `atStation` = title of the last
    split with any recorded time.
  - `.expected` — no time here, but has a time at an earlier split, not dropped.
  - `.notStarted` — no recorded times at all.
  Sort key: index of furthest split reached (desc), then time at the selected
  split (asc) for those through it, then bib.

### Pure helpers (own file(s), unit-tested)
- **Status derivation** — the `.finished/.through/.dropped/.expected/.notStarted`
  logic, as a free function over an `EffortRow` + split index + headers.
- **Elapsed formatting** — `Date - eventStart` → `H:MM` (or `HH:MM`),
  hours can exceed 24 (no day rollover for elapsed).
- **Time-of-day formatting** — local `HH:mm`, with a `+Nd` suffix when the
  station's date is N days after the event start date.
- **Runner filter** — case-insensitive match of a query against bib (prefix)
  or first/last name (substring).

### Menu wiring
Add a **"Race Status"** button to `OSTRightMenuViewController` that sets the
drawer's `centerViewController` to a new `RaceStatusViewController` (mirroring
the existing Cross Check / Utilities actions). Pass the currently-selected
event group id the same way the other read screens obtain it.

## Data flow

```
open screen
  → eventsInGroup(groupId)
      → 1 event:  hide selector, select it
      → >1 event: show selector, default to first
  → spread(selectedEventSlug)        [spinner]
      → decode EventSpread (held in memory)
      → render current mode from memory
toggle mode / pick runner / pick station → re-render from memory (no network)
Refresh button → spread(selectedEventSlug) again
change event → spread(newSlug)
```

## Error handling

- Network/auth failures surface through the existing `UIViewController+OSTAlert`
  with a retryable message; spinner via `UIViewController+OSTSpinner`.
- Empty event group (no events) → empty state with a message.
- A selected runner/station with no data renders an explicit empty row, not a
  crash.

## Testing

Unit tests (XCTest, existing `FixtureLoader` + golden-style patterns), using the
committed `spread-test-lonesome-100.json` fixture:
- **Envelope parsing** — `EventSpread.decode` produces the right counts
  (18 split headers, 151 efforts), aligns `absoluteTimes` to headers, parses
  dates with offset, handles `null` sub-splits.
- **Status derivation** — finished / through / dropped@station / expected /
  not-started for representative rows.
- **Elapsed & time-of-day formatting** — including a station that rolls to the
  next day (`+1d`).
- **Field sorting** — order by furthest progress then split time.
- **Runner filter** — bib prefix and name substring matching.

## Out of scope (v1)

- Auto-refresh / polling.
- Offline cache / CoreData persistence (live API only).
- Distance or pace columns (station name + times only).
- Charts / graphical timeline.
- Editing or submitting from this screen (read-only).
