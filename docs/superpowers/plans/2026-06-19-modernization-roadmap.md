# OST Remote — Full Modernization Roadmap

Target: pure **Swift + UIKit**, iOS 12–26, no CocoaPods, modern CoreData + networking.
Strategy: **migrate screen UI to Swift first** (reusing Obj-C data/network via the bridge — the proven Login/About/Utilities pattern), then do the cross-cutting layer swaps. Each phase ships and is verifiable. Verification of UI is done by the user (sim automation is finicky — see memory `batch-autonomous-then-human-verify`).

## Phase 0 — Foundations ✅
Build on Xcode 26; Swift `APIClient`/`CoreDataStack`/`SyncService`; Login screen (Swift); safe-area fixes on all screens; keychain crash fix.

## Phase 1 — Warm-up screens ✅
**About** + **Utilities** → Swift (`@objc`, keep XIB, subclass `OSTBaseViewController`); `OHAlertView` → `UIAlertController`. Also: copyright © 2026, version 4.0.0 (dynamic).

## Phase 2 — Data-entry screens (the heart)
Event/Aid selection → Review/Sync → Cross Check → Live Entry (+ Swift reimpl of `APNumberPad`). Each Swift, still using Obj-C network + MagicalRecord via bridging, **verified per-screen** against the live test event.
- **UX cleanup to fold in:** the event/aid-selection dropdowns show a floating blue circle-checkmark (`btnNext`, the "Begin Tracking" asset) above the picker — looks awkward/redundant. Redesign the dropdown confirm UX (confirm-on-select or a proper toolbar "Done"); drop the floating checkmark.

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
