# Event-Selection: Pickers & Loading Rework — Design

**Date:** 2026-06-20
**Branch:** worktree-login-event-redesign (already merged once to swiftui-rewrite; this is a follow-up)
**Status:** Approved (brainstorm), pending implementation plan

## Goal

Improve the redesigned event-selection screen based on use feedback:
1. **Events as an open selector** — show the (usually 1–3, live-mode-only) events directly as selectable rows, no tap-to-reveal.
2. **Aid station as a bottom drawer** — the longer, variable station list opens in a slide-up bottom sheet.
3. **Visible loading** — present the screen immediately with a centered "Loading events…" spinner instead of a silent pause on the login screen.
4. **Title + instructions** — the screen had neither.

## Context & constraints

- iOS 12 floor (iPad mini 2/3). **No `UISheetPresentationController`** (iOS 15+) — the bottom drawer is a custom, programmatic component.
- Design-system rules from [[ost-visual-language]]: all styling via `Theme` roles; build programmatically with safe-area Auto Layout; no raw colors.
- The current screen uses `DisclosureSelectField` (inline-expand) for both Event and Aid Station. This rework replaces both controls, leaving `DisclosureSelectField` with **zero consumers** → it is removed (see below).
- Event list is short because only "live mode" events appear ([[ost-event-selection-live-mode]]).
- Preserve the data path and public `@objc` API of `OSTEventSelectionViewController` (the two callers — `LoginViewController`, `OSTUtilitiesViewController.onChangeStation` — stay unchanged in their call sites).

## Decisions (from brainstorm)

- **Events:** open selector (vertical selectable rows with a radio indicator), shown directly. Auto-select when exactly one event (existing behavior). A long list simply scrolls (rare).
- **Aid station:** tappable field that opens a **bottom drawer** (dimmed scrim + slide-up panel + grab handle + scrollable list). Selecting a station closes the drawer, shows the selection, and reveals "Start Tracking".
- **Loading:** the event screen is presented immediately and shows a centered spinner + "Loading events…" until the events fetch returns, then renders the open selector.
- **Title/instructions:** title "Select Event & Aid Station", hint "Choose your event, then your aid station."

## Architecture

### New components (in `OST Tracker/Swift/DesignSystem/`)

**`SelectableOptionList: UIView`** — the open selector.
- `init(label: String)`; `var options: [String] { didSet }` (rebuilds rows); `private(set) var selectedOption: String?`; `var onSelect: ((String) -> Void)?`; `func select(_:)`; `func reset()`.
- Renders a section label + one tappable row per option (themed: `fieldFill`, `separator`, `label`), each with a trailing radio indicator filled (`tint`) when selected. Single-select. Theme-only styling.

**`BottomSheetPicker`** — the aid-station drawer. A small, self-contained presentation helper:
- `static func present(from presenter: UIViewController, title: String, options: [String], selected: String?, onSelect: @escaping (String) -> Void)`.
- Implemented as a `UIViewController` with `modalPresentationStyle = .overFullScreen`, a tap-dismissable dimmed scrim, and a bottom-anchored rounded panel (grab handle, title, scrollable list of rows; selected row checked in `tint`). Slide-up/down animation via constraint + `UIView.animate`. No iOS 15 APIs. Theme-only styling.

### Screen: `OSTEventSelectionViewController`

- Add a **title label** (`Theme.Font.title`) and a **hint label** (`Theme.Font.field`, `Theme.secondaryLabel`) at the top.
- Replace the Event `DisclosureSelectField` with a `SelectableOptionList`.
- Replace the Aid Station `DisclosureSelectField` with a **tappable field row built inline in the VC** (not a new design-system component): a themed `UIControl` showing the "Aid Station" label + current value (or placeholder) + chevron, styled from `Theme` (`fieldFill`, `separator`, `label`/`secondaryLabel`). Tapping it calls `BottomSheetPicker.present(...)`; on selection it stores the choice, updates the field's displayed value, and reveals "Start Tracking". It is disabled until an event is selected.
- **Loading state:** a centered `UIActivityIndicatorView` + "Loading events…" label, shown while events load, hidden once the selector is populated.

### Loading flow change

Today `loadEventDataAndPresent(from:)` fetches events **then** presents. Change to **present first, load inside**:
- `loadEventDataAndPresent(from:completion:)` now creates the VC, presents it immediately (fullScreen) in its loading state, then triggers the events fetch (in the VC). The method keeps its `@objc` signature so `LoginViewController` is unchanged; `LoginViewController` stops its own button spinner once the screen is presented.
- The events fetch (`OSTBackend.getAllEvents` + `EventModel.mr_import` + sort + build `eventStrings`) moves into the VC. On success: populate the `SelectableOptionList`, hide the spinner, auto-select if one event.
- **Error / no events:** show the existing alerts **on the event screen** now (it is already presented). "Try Again" re-runs the fetch. For "No Events Available" (and unrecoverable errors), clear the token and **dismiss back to login** so the user isn't stranded.
- `changeStation` mode does no events fetch (data is already in `CurrentCourse`); it skips the loading state, shows the current event as a single selected (non-interactive) row, and opens straight to aid-station selection via the drawer.

### Removal

Delete `DisclosureSelectField.swift` and `DisclosureSelectFieldTests.swift` (zero consumers after this change) and de-register them from `project.pbxproj`. This keeps the design system free of dead code.

## Data flow

Unchanged after a station is chosen — `onNext` still reads `selectedEvent` + the chosen station title, calls `OSTBackend.getEventsDetails`, builds `CurrentCourse` (all existing fields), `EffortModel.mr_reconcile`, saves, and routes to the tracker. Only the *source* of the selections changes (open selector + drawer instead of two disclosure fields), plus the relocated events fetch.

## Testing

- **Unit:** `SelectableOptionList` (select sets selection + fires callback; reset clears; options rebuild). `BottomSheetPicker` selection callback fires the chosen option. (Presentation/animation verified manually.)
- **Existing:** the `onNext` data path is unchanged; covered by the existing flow.
- **Manual (human verify):** loading spinner on entry; open event selector with 1 / 2–3 / many events; aid-station drawer open/scroll/select/dismiss; Start Tracking gating; changeStation mode; no-events → returns to login; light + dark.

## Risks & mitigations

- **Present-first flow** changes where error/no-events alerts appear and adds a dismiss-to-login path. Mitigation: explicit handling above; manual verification of the no-events and error paths is on the list.
- **Custom bottom drawer on iOS 12** — no system sheet API; implement with overFullScreen + constraint animation (well-trodden pattern). Verify dismiss-on-scrim-tap and that it doesn't trap the user.
- **Two interaction patterns on one screen** (open list + drawer) — intentional hierarchy (primary small choice open, secondary long choice in a drawer); validated in the mockup.

## Out of scope

- Other screens; networking/CoreData/sync logic; the design-system theme/color layer (unchanged). The Appearance toggle and login screen are untouched.
