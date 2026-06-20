# Login & Event-Selection Redesign — Design

**Date:** 2026-06-20
**Branch:** swiftui-rewrite
**Status:** Approved (brainstorm), pending implementation plan

## Goal

Establish a shared visual identity (a lightweight design-system layer) and apply it
to the two entry screens of OST Remote — **Login** and **Event Selection** — within
the app's iOS 12 / UIKit floor (iPad mini 2/3). No SwiftUI.

The login screen is already a clean programmatic safe-area layout and needs only a
restyle onto the new theme. The event-selection screen still carries the legacy
XIB design (full-screen background image, hand-styled white-bordered dropdowns,
triangle chrome, a manual safe-area shift hack, keyboard-wheel pickers) and gets a
full presentation rewrite.

## Context & constraints

- **iOS 12 floor.** No system dark mode, no dynamic `UIColor` providers, no
  `overrideUserInterfaceStyle` on iOS 12. The design must degrade to light-only
  there with no branching at call sites.
- **Field use.** Volunteers use this at remote aid stations, often outdoors. Light
  is the default (the user finds dark harder to read in glare); dark is opt-in via
  the system setting or a manual toggle.
- **Event lists are short.** Events only appear here when the organizer has put them
  in "live mode," so the picker never faces a long list — this is why the picker is
  inline-expand with no search.
- **Presentation rewrite, not logic rewrite.** The event-selection data flow
  (network load, CoreData import, `CurrentCourse`, logout connectivity check) is
  untouched. Only view construction and interaction change.
- **Callers are stable.** Both `LoginViewController` and
  `OSTUtilitiesViewController.onChangeStation` instantiate
  `OSTEventSelectionViewController(nibName: nil, …)` and use only its public API
  (`changeStation`, `loadEventDataAndPresent(from:completion:)`, `present`). The XIB
  can be removed without changing either caller.

## Decisions (from brainstorm)

1. **Scope:** Full visual identity — design-system layer + both screens.
2. **Direction:** Native iOS look, **light default**.
3. **Theming:** light default; follow system on iOS 13+; light-only on iOS 12;
   semantic color roles only (no raw colors at call sites); manual *System · Light ·
   Dark* toggle in Utilities, persisted, iOS 13+ only.
4. **Picker interaction:** inline-expand (the list drops in place under the row and
   collapses on selection). No modal, no search.

## Architecture

### 1. Design-system layer

A small, dependency-free Swift layer. No screen names a raw color — only a role.

**Semantic color roles:** `background`, `secondaryBackground`, `fieldFill`,
`separator`, `label`, `secondaryLabel`, `tint` (brand blue), `success` (green
primary action), `destructive` (red / logout).

**Light + dark palettes** for those roles:
- On **iOS 13+**, each role is a dynamic `UIColor` built with the
  `UIColor(dynamicProvider:)` initializer, so light/dark resolves automatically from
  the trait collection.
- On **iOS 12**, the dynamic initializer is unavailable; the layer returns the
  **light** value directly. This is gated once, inside the theme layer, so call
  sites are identical on every OS version.

**Typography & metrics:** named text styles (title, field, button, caption/label)
and shared constants (corner radius, field height, standard insets) so spacing is
consistent across both screens.

**`AppearanceController`:** reads/writes the user's choice
(`system` | `light` | `dark`) to `UserDefaults` and applies it via the app window's
`overrideUserInterfaceStyle` on iOS 13+. No-op on iOS 12. Applied at launch and
whenever the toggle changes.

### 2. Reusable components

- **`PrimaryButton`** — filled action button (login "Log In", event-selection
  "Start Tracking"), styled from the theme.
- **`StyledTextField`** — the login field treatment, moved behind the theme
  (today's `makeField` logic).
- **`DisclosureSelectField`** — the inline-expand picker. A tappable row showing a
  label, the current value (or placeholder), and a chevron; tapping expands a short
  list of options in place and collapses on selection. Self-contained: takes
  `[String]` options + a selection callback, exposes the current selection. Used for
  both Event and Aid Station.

Each component depends only on the theme layer and is unit-testable in isolation.

### 3. Login screen (`LoginViewController`)

Restyle only; behavior unchanged.
- Pull colors / fonts / metrics from the theme instead of hardcoded values.
- Remove the unused `brandBlue` constant.
- Use `PrimaryButton` and `StyledTextField`.
- Keep the existing safe-area stack-view layout and the login → event-selection
  handoff exactly as-is.

### 4. Event-selection screen (`OSTEventSelectionViewController`) — rewrite

Retire `OSTEventSelectionViewController.xib`; build views programmatically.

**Remove:**
- the full-screen background image,
- the triangle indicator images (`imgTriangleAidStation`, `eventTriangle`),
- the `viewDidLayoutSubviews` manual safe-area shift hack (safe-area Auto Layout
  makes it unnecessary),
- the keyboard-wheel `OSTDropDownField`s.

**Build:**
- a clean themed background with safe-area-pinned content,
- two `DisclosureSelectField`s — **Event**, then **Aid Station** (Aid Station
  revealed once an event is chosen),
- a `PrimaryButton` ("Start Tracking" / live-entry action),
- a `Log Out` action (destructive role) in the initial mode; a `Cancel` action in
  `changeStation` mode,
- the existing progress label + progress bar for the post-selection download state,
  restyled.

**Keep both modes** — initial selection and `changeStation` (Utilities → Change
Station) — driven by which fields are shown rather than `alpha`/`isHidden` juggling.
All data flow (`loadEventDataAndPresent`, `getEventsDetails`, `CurrentCourse`
creation, `EffortModel.mr_reconcile`, logout connectivity check) is preserved
verbatim.

**Public API is unchanged:** `@objc var changeStation`, `@objc class func
loadEventDataAndPresent(from:completion:)`, and the `@objc(OSTEventSelectionViewController)`
name all stay so the two existing callers keep working untouched.

### 5. Utilities — Appearance toggle (`OSTUtilitiesViewController`)

A new row opening a *System · Light · Dark* selection, wired to
`AppearanceController`. **Hidden entirely on iOS 12** (no theme to switch to).

## Data flow

Unchanged from today. The redesign touches view construction and the picker
interaction only:

```
LoginViewController.didTapLogin
  → LoginController.login → addToken
  → OSTEventSelectionViewController.loadEventDataAndPresent(from:)
        → OSTBackend.getAllEvents → EventModel.mr_import → present(eventVC)
            → user selects Event (DisclosureSelectField) → reveal Aid Station
            → user selects Aid Station → "Start Tracking"
                → OSTBackend.getEventsDetails → CurrentCourse + mr_reconcile
                → AppDelegate.loadLeftMenu / showTracker
```

## Testing

- **Unit:** `AppearanceController` persistence + role resolution (light on iOS 12,
  dynamic on iOS 13+); `DisclosureSelectField` selection callback and
  expand/collapse state.
- **Existing coverage:** the data-loading path is untouched, so its current behavior
  remains covered by the existing flow/tests.
- **Manual (human verify, per project workflow):** live login → event → aid station →
  tracker on device/sim; light look; system-dark auto-switch on an iOS 13+ device;
  the Utilities toggle.

## Risks & mitigations

- **Removing the XIB.** Mitigated: both callers use `nibName: nil` and only the
  public API; grep confirmed no external references to the XIB's outlets. Verify the
  grep again at implementation time before deleting the XIB.
- **iOS 12 API gaps.** All dark-mode APIs (`dynamicProvider`,
  `overrideUserInterfaceStyle`) are guarded with `@available` / `#available`; iOS 12
  resolves to light with no call-site branching.
- **`changeStation` regression.** Both modes share the same fields; the mode is a
  visibility decision. Manual verification of Change Station is on the verify list.

## Out of scope

- Restyling other screens (tracker, cross-check, review/submit). The design-system
  layer is built so they *can* adopt it later, but this work stops at login,
  event-selection, and the Utilities toggle.
- Any change to networking, CoreData, or sync logic.
