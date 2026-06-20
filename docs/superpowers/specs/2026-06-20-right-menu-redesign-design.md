# Right-Menu Redesign — Design

**Date:** 2026-06-20
**Branch:** worktree-menu-redesign (off swiftui-rewrite)
**Status:** Approved (brainstorm), pending implementation plan

## Goal

Rework the right-side navigation drawer (`OSTRightMenuViewController`) onto the design system: a clean, legible themed list instead of text floating over a forest photo. Fixes the legibility, inconsistent separators, and badge placement seen in the field, and makes the drawer follow light/dark like the rest of the migrated screens.

## Context & constraints

- iOS 12 floor (iPad mini 2/3). No SF Symbols / iOS 15 APIs; guard any iOS 13+ call.
- Design-system rules from [[ost-visual-language]]: style only via `Theme`; build programmatically with safe-area Auto Layout; no raw colors; no XIB.
- **How it's wired (must preserve):**
  - `AppDelegate.rightMenuVC` is an `OSTDrawerContainer`; the menu panel is its `rightMenuViewController`, created as `[[OSTRightMenuViewController alloc] initWithNibName:nil bundle:nil]`. The container sizes/positions the panel.
  - `OSTRightMenuViewController` subclasses the Obj-C `OSTBaseViewController` (`AutoSyncObserver`), which provides the badge plumbing (`badge`, `shouldShowBadge`, `updateSyncBadge`, the `syncManagerDid…` callbacks).
  - Nav actions today: Live Entry → `AppDelegate.showTracker`; Review / Sync → `showReview` (carries the unsynced-count badge); Cross Check → `CrossCheck.storyboard`; Live Reads → `OSTLiveReadsViewController`; Race Status → `OSTRaceStatusViewController`; Utilities → `showUtilities`; Close → `OSTDrawerContainer.toggleRightSideMenuCompletion` (and refocus the bib field if the center is the tracker). Auto Sync switch → `AutoSyncController.shared.autoSyncEnabled`.
- The Obj-C `OSTRightMenuViewController` cannot reference the Swift `Theme` (Theme is a non-`@objc` Swift enum), which is the core reason this becomes a Swift rewrite rather than an in-place restyle.

## Decisions (from brainstorm)

- **Direction A — clean themed list.** Solid `Theme.background`; no background photo or cover overlay.
- **No row icons** — plain label + chevron rows (iOS 12-safe, zero asset work).
- **Auto Sync** stays a pinned row at the bottom of the panel.

## Architecture

### Rewrite `OSTRightMenuViewController` as programmatic Swift

`@objc(OSTRightMenuViewController) final class OSTRightMenuViewController: OSTBaseViewController`
- Keeps the `@objc` name and `init(nibName:bundle:)` so `AppDelegate` and `OSTDrawerContainer` are unchanged. With no XIB, `initWithNibName:nil` yields an empty view that this class builds programmatically.
- Subclasses the existing Obj-C `OSTBaseViewController`; overrides `updateSyncBadge()` (drive the Review/Sync badge) and the `syncManagerDidStartSynchronization:` / `…DidFinish…` / `…didFinishSynchronizationWithErrors:` callbacks (show/hide the sync spinner), each calling `super`.
- Builds the UI in `viewDidLoad` with safe-area Auto Layout. Retires `OSTRightMenuViewController.xib` and removes the manual `viewDidLayoutSubviews` safe-area shift hack, the forest `rightMenuBackImage`, the `coverView`, and the hand-placed separator/rearrange logic.

### New component: `MenuRow` (design system)

`OST Tracker/Swift/DesignSystem/MenuRow.swift` — `final class MenuRow: UIControl`:
- `init(title: String)`; a themed row showing the title (`Theme.label`, `Theme.Font` ~17/semibold) on the left and a trailing chevron (`Theme.secondaryLabel`).
- `var badgeCount: Int { get set }` — shows a red count pill (`Theme.destructive`, white text) when `> 0`, hidden otherwise.
- `var showsSpinner: Bool` (optional) — a small `UIActivityIndicatorView` for the syncing state on the Review/Sync row.
- Theme-only; re-resolves any `cgColor` in `traitCollectionDidChange`.

### Panel layout

- Header row: a **Close** button (trailing, `Theme.tint`, "Close ✕") wired to `onClose`.
- Brand: OST logo image + "OST Remote" label (`Theme.Font.title`-scale).
- A grouped container (`Theme.secondaryBackground`/`fieldFill`, rounded `Theme.Metric.cornerRadius`) holding the six `MenuRow`s in order with inset hairline separators (`Theme.separator`).
- Pinned bottom: an **Auto Sync** row (`Theme.label` label + `UISwitch`), reading/writing `AutoSyncController.shared.autoSyncEnabled`.
- Each row wired by `addTarget` to the existing action bodies (unchanged behavior).

## Data flow

Unchanged. Each row triggers the same `AppDelegate`/drawer calls as today; the badge value comes from the `OSTBaseViewController` plumbing via the overridden `updateSyncBadge()`; the spinner reflects `AutoSyncController.shared.isSyncing` via the observer callbacks.

## Testing

- **Unit:** `MenuRow` — `badgeCount > 0` shows the pill with the right text and `== 0` hides it; title is set. (Nav actions are thin `AppDelegate` calls with no new logic → build + manual.)
- **Existing:** full suite stays green; `AppDelegate`/container untouched so the panel still instantiates.
- **Manual (human verify):** open drawer; each item navigates correctly; Review/Sync badge reflects the unsynced count and clears after sync; the sync spinner shows while syncing; Auto Sync toggle persists; Close works (and refocuses the bib field on the tracker); light + dark; no content under the Dynamic Island.

## Risks & mitigations

- **Swift subclass of the Obj-C base.** Overriding the `@objc` `AutoSyncObserver`/badge methods must call `super`; verify the badge still updates and the observer is still registered (the base handles registration). Manual badge/sync verification is on the list.
- **Panel sizing by the drawer container.** The panel's view frame is provided by `OSTDrawerContainer`; using safe-area Auto Layout adapts to whatever width/height it's given (retiring the fixed XIB frames + shift hack).
- **Instantiation.** Removing the XIB changes `initWithNibName:nil` from nib-loading to empty-view; the class must build its view in code. Verified the only caller is `AppDelegate` via that initializer.

## Out of scope

- The `OSTDrawerContainer`, `AppDelegate`, the destination screens, and `OSTBaseViewController` itself. Other unmigrated screens (tracker, edit-entry, cross-check, review/submit, about) — separate efforts.
