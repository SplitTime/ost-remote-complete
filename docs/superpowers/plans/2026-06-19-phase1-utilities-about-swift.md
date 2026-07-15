# Phase 1 — Migrate About + Utilities to Swift

**Goal:** Convert `OSTAboutViewController` and `OSTUtilitiesViewController` from Objective-C to Swift, with no UI/behavior change, replacing `OHAlertView` with native `UIAlertController`. Establishes the Swiftification pattern for the remaining screens.

**Approach (low-risk, autonomous-verifiable):** Replace each `.h/.m` with a `.swift` class of the **same `@objc` name** (`@objc(OSTAboutViewController)`), subclassing `OSTBaseViewController`. **Keep the existing XIB** (already safe-area-fixed) — its custom class still resolves to the same name, and `@IBOutlet`/`@IBAction` connect by name. `AppDelegate` still does `[[OSTAboutViewController alloc] initWithNibName:nil bundle:nil]` (the XIB auto-loads); only its `#import` lines change to rely on the generated Swift header. Build-green ≈ working, since layout + outlet wiring are unchanged.

## Prep
- Bridging header: add `OSTBaseViewController.h` and `UIViewController+OSTSafeArea.h` so Swift can subclass the base and call `ostApplySafeAreaFix` / `ostPositionBadgeAtMenu`.
- `AppDelegate.m`: remove `#import "OSTAboutViewController.h"` and `#import "OSTUtilitiesViewController.h"` (Swift classes are visible via `OST_Remote-Swift.h`, already imported).

## Task 1: About (clean — no network/MR)
- Delete `OSTAboutViewController.h/.m`; add `OSTAboutViewController.swift`:
  - `@objc(OSTAboutViewController) class OSTAboutViewController: OSTBaseViewController`
  - `@IBOutlet` for `lblTitle, targetLbl, versionLbl, primaryLbl, fallBackLbl`.
  - `viewDidLoad`: set the four labels from the bundle/Info.plist (drop the `IS_IPHONE_X` tweak — safe-area fix handles it).
  - `viewDidLayoutSubviews`: `ostApplySafeAreaFix()` + `ostPositionBadgeAtMenu()`.
  - `@IBAction onMenu` (toggle drawer via `AppDelegate.getInstance()?.rightMenuVC...`) and `onReturnToLiveEntry` (`showTracker`).
  - Needs `import MFSideMenu` for the drawer toggle.
- Update project (remove old refs, add swift). Build `OST Remote` → green.

## Task 2: Utilities (network + MagicalRecord + alerts)
- Delete `OSTUtilitiesViewController.h/.m`; add `OSTUtilitiesViewController.swift`:
  - Same base/outlet pattern. Outlets: `lblTitle, loadingView, lblYourDataIsSynced, imgCheckMark, lblSuccess, activityIndicator, progressBar, btnReturnToLiveEntry, lblSyncing, logoImage, remoteLbl, btnRetry`.
  - Port: `viewDidLoad`, `viewWillAppear`, `showLoadingScreen`, `showLoadingValues`, `showFinishLoadingValues`, `showFinishLoadingErrorValues`, `onRefreshData` (network `getEventsDetails` + `EffortModel.mr_import` + `CurrentCourse` updates + `MR_save` — `import MagicalRecord`), `onReturnToLiveEntry`, `onAbout`, `onMenu`, `onChangeStation` (present `OSTEventSelectionViewController` with `changeStation = true`), `onLogout`.
  - Replace both `OHAlertView` logout dialogs with `UIAlertController` (alert style; "Cancel" + "Logout"/"Ok").
- Build → green.

## Verification (hand to user)
After both build green, user navigates: open menu → **Utilities** (check layout, badge, buttons; tap **Refresh Data** → loading→success; **About** → labels correct, **Return To Live Entry**, **Logout** confirm dialog). Report issues.

## Notes
- No data migration; still uses Obj-C `OSTNetworkManager` + MagicalRecord via bridging (those layers migrate in later phases).
- Keeping the XIBs is intentional for Phase 1; converting to programmatic Auto Layout can come later if desired.
