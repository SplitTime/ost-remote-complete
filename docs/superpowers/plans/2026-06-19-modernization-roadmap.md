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

## Phase 3 — Drawer shell → drop MFSideMenu (deferred; pure refactor, low value/high risk)
Native Swift right-side drawer container; remove `MFSideMenu`. Deprioritized vs. Phase 4 — it's a no-user-facing-change refactor with app-wide navigation risk and is hard to verify (sim drawer driving is unreliable). Do when convenient.

## Phase 4 — Networking: AFNetworking → `APIClient` ✅ DONE
Routed every endpoint through the Swift `APIClient`/`OSTBackend` (URLSession) and **dropped AFNetworking** (commit `8a57249`, 14→13 pods). `OSTNetworkManager` is now a plain `NSObject` token-holder + native reachability (`OSTReachability`/`NWPathMonitor`); deleted the dead Obj-C category methods, `JSONResponseSerializerWithData`, and `OSTLoginViewController`. Golden-master payload test still green.
- **✅ Login POST migrated + both networking bugs fixed** (commit `1f5d782`). Root cause of the Refresh-Data 400 **and** the logout false-"disabled": `autoLogin`'s `POST /auth` went through AFNetworking, whose credential encoding the server rejected (400 "Invalid email or password") — even for valid stored creds that logged in fine via `APIClient`. Fix: `@objc OSTAuthBridge` routes the login POST through `APIClient`; `OSTNetworkManager.loginWithEmail` calls it. (Also fixed `addTokenToHeader` `"bearer (null)"`.) Confirmed on device.
- **✅ All read endpoints migrated** (commit `a9968d9`): `getAllEvents`/`getEventsDetails`/`fetchNotExpected` now run through `OSTBackend` (Swift `APIClient`, raw JSON). Confirmed on device (Refresh Data + Cross Check).
- **✅ Entry submit transport migrated** (commit `f2c9664`): the live `event_groups/{id}/import` POST now goes over `URLSession` via `OSTBackend.postJSONToURL`. Surgical — the Obj-C still builds the exact same payload and keeps the `OSTSyncManager` batching/retry/alternate-server orchestration; only transport moved (golden guard unaffected). Confirmed syncing live on device.
- **➡️ Final cleanup remaining to drop AFNetworking (next batch):** AFNetworking is now dead-weight only. To remove the pod: (1) make `OSTNetworkManager` an `NSObject` (not `AFHTTPSessionManager`) holding just an auth-token string (`addTokenToHeader` sets it; the submit reads it); (2) replace `reachabilityManager` (used by Utilities logout + AppDelegate) with native `NWPathMonitor` (iOS 12+) — also pre-does Phase 6's Reachability drop; (3) delete the now-unused Obj-C category GET/POST methods + `JSONResponseSerializerWithData`; (4) `NSError errorsFromDictionary` degrades gracefully (URLSession errors lack the AF userInfo key) — fine; (5) remove AFNetworking from the Podfile + `pod install`. Then full-surface re-verify (login, reads, submit, both logouts). This is core-network surgery — do as its own focused batch.

## Phase 5 — Data layer: MagicalRecord → `CoreDataStack`
Replace `MR_*` with typed `NSPersistentContainer` fetches/saves on the same store (no data migration). Drop MagicalRecord.

## Phase 6 — Retire remaining pods + drop CocoaPods (started)
- **✅ Dropped 7 already-unused pods** (commit `e369aea`, 13→6): OHAlertView, DejalActivityView, Reachability, SimpleKeychain, JTObjectMapping, FXKeychain, NSDate+Helper — all made dead by the UI/networking migrations.
- **✅ Dropped CHCSVParser + Toast** (commit `9b526d6`): CSV export builds the string directly (RFC-4180 escaping); the sync toast is a native fading `UILabel`.
- **✅ Dropped IQKeyboardManager** (commit `ec93325`): its keyboard-avoidance was vestigial (every field sits above its bottom inputView), so just removed the enable/toolbar calls + the pod.
- **✅ Dropped IQDropDownTextField → native `OSTDropDownField`** (commit `1c1ecca`): a small UITextField + UIPickerView/UIDatePicker that reproduces the used API; swapped XIB custom classes + outlet types on event/station/sort/date fields.
- **Remaining 2 pods:** `MagicalRecord` (Phase 5 — big, all Core Data) and `MFSideMenu` (Phase 3 drawer). After both, delete the Podfile / move any kept deps to SPM — CocoaPods-free.

## Phase 7 — Optional: lift the floor
If iPad mini 2/3 retire, bump deployment target → unlock async/await + SwiftUI for future features.
