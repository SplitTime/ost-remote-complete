# OST Remote — Full Modernization Roadmap

Target: pure **Swift + UIKit**, iOS 12–26, no CocoaPods, modern CoreData + networking.
Strategy: **migrate screen UI to Swift first** (reusing Obj-C data/network via the bridge — the proven Login/About/Utilities pattern), then do the cross-cutting layer swaps. Each phase ships and is verifiable. Verification of UI is done by the user (sim automation is finicky — see memory `batch-autonomous-then-human-verify`).

## Phase 0 — Foundations ✅
Build on Xcode 26; Swift `APIClient`/`CoreDataStack`/`SyncService`; Login screen (Swift); safe-area fixes on all screens; keychain crash fix.

## Phase 1 — Warm-up screens ✅
**About** + **Utilities** → Swift (`@objc`, keep XIB, subclass `OSTBaseViewController`); `OHAlertView` → `UIAlertController`. Also: copyright © 2026, version 4.0.0 (dynamic).

## Phase 2 — Data-entry screens (the heart)
Event/Aid selection ✅ → Review/Sync ✅ → Cross Check ✅ → Live Entry ✅. **Phase 2 complete — all four main screen VCs are now Swift**, each verified on device against the live test event. (`APNumberPad` kept as Obj-C per user — reimplement in Swift later as its own task.)
- **Live Entry (runner tracker) — done & verified** (Swift, commit `f985d46`): live clock, in/out entry buttons (all split configs), KVO bib lookup + in/out time badges, entry creation/sounds/runner-badge/notification, pacer/stopped, edit-entry, digit-only/max-4 guard, rotation. Kept APNumberPad/OSTSound/OSTRunnerBadge as Obj-C. **Fixed a launch crash:** unconnected outlets (`lblWithPacer`, `timeContainerView`) are silently-nil in Obj-C but crash Swift's implicit-unwrap — made optional. See `ost-swift-migration-gotchas` memory.
- **Phase 2.5 — Edit/Create-Entry screen → Swift, done & verified** (`OSTEditEntryViewController`, commits `3637b3d`+; shared by Review/Sync + tracker). Edit + create-new flows ported (bib lookup, time/date pickers, pacer/stopped, update, delete). **Fixed the "weird" toolbar** (`enableAutoToolbar` YES→NO removed the stray Done bar over the number pad) **and the date editor** (IQDropDownTextField's `UIDatePicker` defaulted to the iOS-14+ compact "pill" → forced `.wheels`). Dropped the dead iPhone-X/XR nudge; `lblWithPacer` (unconnected outlet) made optional; OHAlertView→UIAlertController. Confirmed on device.

**➡️ With Phase 2 + 2.5 done, the entire UI surface is Swift.** Next: the cross-cutting phases below (3→6), plus the remaining `APNumberPad` Swift reimpl whenever convenient.
- **Cross Check — done & verified** (Swift, commit `758e768`): collection view + in/out segmented header, 5-way checkmark filters with live counts, slide-up effort popup (expected/not-expected toggle), bulk-select mode, not-expected network fetch + CrossCheckEntries CoreData writes. Keeps `CrossCheck.storyboard` + Obj-C cells. `DejalBezelActivityView` → shared `UIViewController+OSTSpinner` (also adopted by Event/Aid). Confirmed on device.
- **Event/Aid selection — done & verified** (Swift, commit `6d2457b`): both modes (initial + changeStation), CoreData import, logout, safe-area all confirmed on device.
- **Review/Sync — done & verified** (Swift, commits `fd1f7aa`..`<height fix>`): table/sort/CSV export/sync-delegate/edit-entry ports; dropped the dead `onSubmit_old:` and the iPhone-X/XR nudge. **Sync-button bug fully fixed:** it was hidden *behind the table* (the button is before the tableView in XIB z-order, so the grown table covered it on tall screens) AND split/mis-sized by the safe-area pass. Fix: insert `btnSync` above the table, match the share button's vertical frame, and inset the table so rows clear it. Confirmed on device.
- **UX cleanup to fold in:** the event/aid-selection dropdowns show a floating blue circle-checkmark (`btnNext`, the "Begin Tracking" asset) above the picker — looks awkward/redundant. Redesign the dropdown confirm UX (confirm-on-select or a proper toolbar "Done"); drop the floating checkmark.

## Known bug — Logout "disabled" false-positive (investigate in Phase 4 networking)
On the event-selection screen, tapping **Logout** shows "Logout is disabled / Please try again when you have an Internet connection" on the **first** attempt every time, even when connected. This is faithful to the original Obj-C (logout runs an `autoLogin` connectivity probe first and the **first** probe errors). Likely the same network-layer flakiness as the `-999 cancelled` fix; pin down the root cause when `OSTNetworkManager` → `APIClient` in Phase 4. User asked to defer.

## Phase 3 — Drawer shell → drop MFSideMenu
Native Swift right-side drawer container; remove `MFSideMenu`.

## Phase 4 — Networking: AFNetworking → `APIClient`
Route all endpoints through the Swift `APIClient`; delete `OSTNetworkManager`; drop AFNetworking + JSON helper pods. Golden-master tests guard payloads.
- **Known issue to fix here:** Refresh Data (`getEventsDetails`) returns 400 for the current course — the endpoint works for valid event-group ids (verified 437/1035 → 200), so it's a stored-`eventId`/legacy-layer issue. Add proper error handling + correct id usage during this migration.

## Phase 5 — Data layer: MagicalRecord → `CoreDataStack`
Replace `MR_*` with typed `NSPersistentContainer` fetches/saves on the same store (no data migration). Drop MagicalRecord.

## Phase 6 — Retire remaining pods + drop CocoaPods
`IQDropDownTextField`→`UIPickerView`, `Toast`/`DejalActivityView`→native, `CHCSVParser`/`NSDate+Helper`/`Reachability`→Foundation/Network, etc. Delete the Podfile; move any kept deps to SPM.

## Phase 7 — Optional: lift the floor
If iPad mini 2/3 retire, bump deployment target → unlock async/await + SwiftUI for future features.
