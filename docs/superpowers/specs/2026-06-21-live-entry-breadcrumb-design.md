# Live Entry breadcrumb on non-live screens

**Date:** 2026-06-21
**Status:** Approved (design)

## Problem

When a steward is on any screen other than Live Entry and a runner shows up
who needs to be timed *right now*, the only path back to bib entry is the
hamburger drawer → "Live Entry" row (two taps, behind a menu). Two screens
(About, Live Reads) papered over this with a pinned full-width "Return/Go to
Live Entry" button, but the other three (Review/Sync, Cross Check, Race
Overview) have no direct affordance — and the two that do are inconsistent with
each other and with the rest of the app.

## Goal

One consistent, always-visible, one-tap "back to Live Entry" affordance on
**every** non-live in-event screen, replacing the ad-hoc bottom buttons.

## Decision

Add a **breadcrumb in a two-line header**: a top utility row holding a
`‹ Live Entry` crumb on the leading edge alongside the screen's existing action
buttons (refresh/export) and the hamburger, with the screen title dropped to its
own prominent line below.

```
┌────────────────────────────────┐
│ ‹ Live Entry        ↻   ☰      │  ← utility row: crumb + actions + menu
│ Race Overview                  │  ← big title on its own line
├────────────────────────────────┤
│  — table rows —                │
└────────────────────────────────┘
```

This is the iOS large-title pattern (back affordance + actions on a utility
bar, prominent title beneath). It gives the title *more* room than the current
single crowded row, never conflicts with the pinned bottom buttons (Sync,
Review →), and reads clearly ("Live Entry" in words, not just an icon).

### Rejected alternatives

- **Single-line leading button** (text or icon) — crowds already-busy headers
  (title + refresh/export + menu). Icon-only loses the clear wording.
- **Breadcrumb-as-title** (`Live Entry › Cross Check`) — eats horizontal width
  and de-emphasizes the current screen name.
- **Bottom paired button** — crowds the Sync/Review rows and forces a new
  bottom bar onto Race Overview.
- **FAB** — least iOS-native, overlaps table rows.

## Scope

**In scope — the five in-event non-live screens:**

- Review/Sync (`OSTReviewSubmitViewController`)
- Cross Check (`OSTCrossCheckViewController`)
- Live Reads (`OSTLiveReadsViewController`)
- Race Overview (`OSTRaceOverviewViewController`)
- About (`OSTAboutViewController`)

**Out of scope:**

- Live Entry / Runner Tracker (`OSTRunnerTrackerViewController`) — it's the
  root/destination; no crumb.
- Login and Event Selection — pre-event/auth screens, not part of in-event
  navigation.

## Approach: shared two-line header component (DRY)

Today each of the five screens hand-rolls its own header, with three different
title fonts (`Font.brand`, `Font.title`, `Font.button`). This work consolidates
them, mirroring the existing "one hamburger menu-button factory across all
headers" (DRY5) consolidation.

### New shared pieces in `DesignSystem`

1. **`configureAsBreadcrumb(target:action:)`** — a `UIButton` factory parallel
   to the existing `configureAsMenuButton`. Renders a `‹ Live Entry`
   text+chevron button, themed (Theme colors/font), with accessibility label
   "Back to Live Entry".

2. **Two-line header builder** — e.g. `ScreenHeader.make(title:trailingActions:onLiveEntry:)`
   that assembles:
   - a utility row: breadcrumb (leading) · spacer · `trailingActions` (caller's
     refresh/export buttons, may be empty) · hamburger (trailing),
   - the title label on its own line below, using one standardized
     `Theme.Font.title`.

   It returns the assembled header view plus a reference to the contained
   hamburger button so the base VC can keep anchoring the sync badge to it.

### Behavior

- Tapping the crumb calls `AppDelegate.getInstance()?.showTracker()` — the same
  call the existing About/Live Reads bottom buttons already use.

### Removals

- Delete the pinned full-width **"Return to Live Entry"** button from About
  (`OSTAboutViewController`) and **"Go to Live Entry"** button from Live Reads
  (`OSTLiveReadsViewController`). The crumb replaces both — one affordance, not
  two.

### Unchanged

- The sync count badge: still anchored to the hamburger via the Obj-C base VC's
  `ostPositionBadgeAtMenu` frame math. The hamburger remains in the (new)
  utility row, so badge positioning is unaffected. Each screen continues to
  assign `menuButton` from the builder's returned hamburger reference.

## Title standardization

All five screen titles adopt a single `Theme.Font.title` on their dedicated
line, replacing the current mix of `brand`/`title`/`button`.

## Testing

Following the existing `MenuRow`/`PrimaryButton`/presentation-test patterns:

- **`configureAsBreadcrumb`** unit test: button title is "Live Entry", has the
  chevron, correct accessibility label, and the target/action is wired.
- **Header builder** presentation test: given a title + trailing actions, the
  returned header exposes the title text, contains the breadcrumb, surfaces the
  trailing actions and hamburger, and returns a non-nil menu button reference
  for badge anchoring.
- **Visual verification** of all five screens (header layout, badge still
  positioned correctly, crumb navigates to Live Entry) is handed to the user
  per the batch-autonomous-then-human-verify workflow.

## Out of scope / non-goals

- No change to the hamburger drawer's "Live Entry" row (it stays as a secondary
  path).
- No change to Live Entry, Login, or Event Selection.
- No new navigation animation; reuse `showTracker()`.
