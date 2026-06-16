# OST Remote — Swift + UIKit Modernization (Design)

**Date:** 2026-06-16
**Status:** Approved design (revised). **Progress:** Foundations ✅ and Login screen ✅ complete (Swift+UIKit, iOS 12, all tests green on branch `swiftui-rewrite`). **Next: Event / Aid selection** (`docs/superpowers/plans/` — write the plan, then execute).

> **Revision (2026-06-16):** SwiftUI was ruled out. The fleet includes **iPad mini 2/3**, which max out at **iOS 12.5**, so the deployment target must remain **iOS 12**. SwiftUI, async/await, and Combine all require iOS 13+. We therefore modernize in **Swift + UIKit** targeting iOS 12 — same incremental, verified, screen-by-screen plan and the same "Modern iOS" visual direction and keep-the-drawer decision; only the UI technology changes. (Filename retains "swiftui" only because the resume cron references this path.)

## Summary

Incrementally rewrite the OST Remote iOS app (currently ~8,400 LOC of Objective-C, XIB-based UIKit, CocoaPods) into **Swift + UIKit**, targeting **iOS 12**, with light visual modernization in the "Modern iOS" direction. The CoreData model and the OpenSplitTime backend contract are preserved exactly; everything else is modernized. The migration is screen-by-screen, each step shippable, gated by **automated** tests so it can run unattended. The Dynamic Island / safe-area bleed is fixed explicitly via safe-area Auto Layout (iOS 11+).

## Goals

- Modern, clean **Swift + UIKit** codebase on **iOS 12+**; remove dead dependencies.
- **No loss of functionality** — verified, not assumed.
- Fix the safe-area / Dynamic Island bleed on all screens.
- Light visual refresh: "Modern iOS" style (clear titles, system colors, inset cards, more whitespace) — achieved with UIKit.
- Keep the right-side drawer navigation interaction (rebuilt in Swift/UIKit).
- Runnable unattended with automated verification gates; one human checkpoint near the end.

## Non-Goals

- No change to the CoreData model schema (`OSTDataModel.xcdatamodeld` kept byte-for-byte).
- No change to the backend API contract / payloads.
- No SwiftUI / async-await / Combine (all iOS 13+); no raising the deployment target above 12.
- No new product features in this effort (feature work follows, on the modernized base).
- Not a bottom-tab-bar redesign — the drawer stays (user decision).

## Constraints

- **Deployment target: iOS 12.0** (set by iPad mini 2/3). Use only iOS 12-available APIs: UIKit, `URLSession` completion handlers, GCD, `Result`, Codable, `NSPersistentContainer`, `safeAreaLayoutGuide`.

## Architecture: keep the spine, replace the plumbing

| Layer | Today | Target |
|---|---|---|
| Data model | `OSTDataModel.xcdatamodeld` + MagicalRecord | Same `.xcdatamodeld`; thin `NSPersistentContainer` store; drop MagicalRecord |
| Networking | AFNetworking 3.2 (EOL) | `URLSession` + **completion-handler** `APIClient` (Result-based, ~7 endpoints) |
| Sync engine | `OSTSyncManager` (delegate/blocks) | Swift `SyncService` with completion handlers; same batch-300 + login-driven alternate server |
| UI | XIBs + 1 storyboard | **Swift + UIKit** view controllers, programmatic Auto Layout pinned to `safeAreaLayoutGuide` (Modern iOS style) |
| Drawer | MFSideMenu (dead) | Swift/UIKit right-side drawer container |
| Number pad | APNumberPad (vendored) | Swift/UIKit keypad component |
| Misc pods | IQKeyboardManager, OHAlertView, Toast, etc. | Native UIKit equivalents, dropped one-by-one |

- New code in **Swift**; existing Obj-C stays compiled until each piece is replaced (mixed target + bridging header).
- New dependencies (if any) via **Swift Package Manager**, not CocoaPods.
- End state: pure Swift + UIKit, same CoreData store, same server contract, no CocoaPods.

## Backend contract (preserved)

Base `https://www.opensplittime.org/api/v1/` (alt over http). Auth: `POST auth` (form `user[email]`,`user[password]`) → `{token, expiration}`; then header `Authorization: bearer <token>`. Endpoints: event_groups list (editable+live), event_groups/{id} details (efforts), event_groups/{id} group (efforts+splits), POST events/{id}/import and event_groups/{id}/import (jsonapi_batch). Full detail in memory `ost-backend-api-and-test-event`.

## Migration strategy (always shippable)

Each new screen is a **Swift + UIKit `UIViewController`** that replaces one Obj-C view controller at a time, presented by the existing app flow. MFSideMenu remains the shell until the end, so the riskiest container swap happens last. Each step is its own commit/PR.

**Sequence:**
1. **Foundations** — Swift bridging; `NSPersistentContainer` store alongside MagicalRecord; `APIClient` reproducing endpoints; verified vs live server + fixtures. No UI change. *(done; APIClient/SyncService converted to completion handlers for iOS 12)*
2. **Login** ✅ — Swift+UIKit `LoginViewController` replaces `OSTLoginViewController`; auth via `APIClient`, creds via `OSTSessionManager`, presents the (still Obj-C) event selection. Safe-area correct, Modern-iOS look. Tests + screenshot verified.
3. **Event / Aid selection** — data fetch + CoreData write path.
4. **Live Entry** (+ keypad component) — the heart; most careful verification.
5. **Cross Check** — grid logic.
6. **Review / Sync** — SyncService against the server.
7. **Utilities / About / right-menu items.**
8. **Replace MFSideMenu** with a Swift/UIKit drawer container — shell becomes pure Swift.
9. **Remove CocoaPods**, delete dead Obj-C, final cleanup.

## Verification (automated, auto-approvable)

Each screen is gated by an XCTest suite run headless via `xcodebuild test`. Green → commit + advance; red → debug, do not advance.

- **Networking contract tests** — `APIClient` builds byte-identical request payloads to the old code (golden master); parses recorded real responses into identical model values.
- **Sync logic tests** — batch-300 + login-driven alternate server reproduced and asserted.
- **CoreData tests** — new store yields identical entity state for identical inputs.
- **Build + launch smoke + safe-area assertion** — app builds, launches in the simulator, and no key view sits above the safe-area top inset / below the home-indicator inset (automated proof the bleed is fixed). Screenshots captured per screen for the human checkpoint.

### Oracle / fixtures

Deterministic, offline oracle:
- **Recorded real responses** for GET endpoints → `Verification/fixtures/` (auth token redacted). Captured & validated against test event 437.
- **Golden-master fixtures** — exact submit payloads (and, where useful, parsed values) hand-derived from / dumped by the OLD Obj-C code, so "matches old behavior" is a hard assertion.
- **Test account** (user-provided, throwaway; real events not live so writes are safe): event "Test Lonesome 100" (id 437), submit to any split (e.g. Raspberry 1). Credentials in local memory, not committed.

## Autonomy & human checkpoint

- Runs unattended (user enabled auto-approve); proceeds screen-by-screen without per-screen human approval; commit per screen as gates pass.
- A **1-hour resume loop** (cron) wakes work if it halts (e.g., token/usage limits) so it continues when limits refresh.
- **One human checkpoint** after the bulk is done (through Review/Sync): a simulator/device build + a short manual checklist + before/after screenshots for a real-device pass.

## Risks & mitigations

- **Subtle sync/cross-check regressions** → golden-master assertions + live test-event submits.
- **APNumberPad / Cross Check grid fidelity** → reproduced as isolated components with behavior tests.
- **Token expiry mid-run** → APIClient re-auth from stored credentials.
- **iOS 12 API ceiling** → restrict to iOS 12-available APIs; no async/await, SwiftUI, or Combine.
- **CoreData store coexistence (MagicalRecord + NSPersistentContainer)** → same model file, same store URL; verified by CoreData tests early.
