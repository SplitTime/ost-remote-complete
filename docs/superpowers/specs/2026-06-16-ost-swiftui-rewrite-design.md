# OST Remote — SwiftUI Rewrite (Design)

**Date:** 2026-06-16
**Status:** Approved design, pending spec review

## Summary

Incrementally rewrite the OST Remote iOS app (currently ~8,400 LOC of Objective-C, XIB-based UIKit, CocoaPods) into Swift/SwiftUI, with light visual modernization in the "Modern iOS" direction. The CoreData data model and the OpenSplitTime backend contract are preserved exactly; everything else is modernized. The migration is screen-by-screen, each step shippable, gated by **automated** tests so it can run unattended. The Dynamic Island / safe-area bleed is resolved as a free consequence of moving to SwiftUI.

## Goals

- Modern Swift/SwiftUI app, no CocoaPods, no dead dependencies.
- **No loss of functionality** — verified, not assumed.
- Fixes the safe-area / Dynamic Island bleed on all screens.
- Light visual refresh: "Modern iOS" style (large titles, system colors, inset cards, more whitespace).
- Keep the right-side drawer navigation interaction (rebuilt natively).
- Runnable unattended with automated verification gates; one human checkpoint near the end.

## Non-Goals

- No change to the CoreData model schema (`OSTDataModel.xcdatamodeld` kept byte-for-byte).
- No change to the backend API contract / payloads.
- No new product features in this effort (feature work follows, on the modernized base).
- Not a bottom-tab-bar redesign — the drawer stays (user decision).

## Architecture: keep the spine, replace the plumbing

| Layer | Today | Target |
|---|---|---|
| Data model | `OSTDataModel.xcdatamodeld` + MagicalRecord | Same `.xcdatamodeld`; thin `NSPersistentContainer` store; drop MagicalRecord |
| Networking | AFNetworking 3.2 (EOL) | `URLSession` + async/await `APIClient` (~7 endpoints) |
| Sync engine | `OSTSyncManager` (delegate/blocks) | Swift `@Observable`/actor SyncService; same batch-300 + alternate-server fallback |
| UI | XIBs + 1 storyboard | SwiftUI (Modern iOS style) |
| Drawer | MFSideMenu (dead) | Native SwiftUI right-side drawer |
| Number pad | APNumberPad (vendored) | SwiftUI keypad component |
| Misc pods | IQKeyboardManager, OHAlertView, Toast, etc. | Native SwiftUI equivalents |

- New code in **Swift**; existing Obj-C stays compiled until each piece is replaced (mixed target + bridging header).
- New dependencies (if any) via **Swift Package Manager**, not CocoaPods.
- End state: pure Swift/SwiftUI, same CoreData store, same server contract, no CocoaPods.

## Backend contract (preserved)

Base `https://www.opensplittime.org/api/v1/` (alt over http). Auth: `POST auth` (form `user[email]`,`user[password]`) → `{token, expiration}`; then header `Authorization: bearer <token>`. Endpoints: event_groups list (editable+live), event_groups/{id} details (efforts), event_groups/{id} group (efforts+splits), POST events/{id}/import and event_groups/{id}/import (jsonapi_batch). Full detail in memory `ost-backend-api-and-test-event`.

## Migration strategy (always shippable)

Each SwiftUI screen is hosted in the live app via `UIHostingController`, replacing one Obj-C view controller at a time. MFSideMenu remains the shell until the end, so the riskiest container swap happens last. Each step is its own commit/PR.

**Sequence:**
1. **Foundations** — Swift bridging; `NSPersistentContainer` store alongside MagicalRecord; `APIClient` (URLSession) reproducing all endpoints; verified vs live server + fixtures. No UI change.
2. **Login** — proves the SwiftUI-hosted-in-UIKit pattern + new auth path.
3. **Event / Aid selection** — data fetch + CoreData write path.
4. **Live Entry** (+ keypad component) — the heart; most careful verification.
5. **Cross Check** — grid logic.
6. **Review / Sync** — SyncService against the server.
7. **Utilities / About / right-menu items.**
8. **Replace MFSideMenu** with native SwiftUI drawer — shell becomes pure SwiftUI.
9. **Remove CocoaPods**, delete dead Obj-C, final cleanup.

## Verification (automated, auto-approvable)

Each screen is gated by an XCTest suite run headless via `xcodebuild test`. Green → commit + advance; red → debug, do not advance.

- **Networking contract tests** — `APIClient` builds byte-identical request payloads to the old code (golden master); parses recorded real responses into identical model values.
- **Sync logic tests** — batch-300, alternate-server fallback, mark-submitted reproduced and asserted vs golden master.
- **CoreData tests** — new store yields identical entity state for identical inputs.
- **Build + launch smoke + safe-area assertion** — app builds, launches in simulator, and no key view sits above the safe-area top inset (automated proof the bleed is fixed). Screenshots captured per screen for the human checkpoint.

### Oracle / fixtures

Deterministic, offline oracle:
- **Recorded real responses** for GET endpoints → `Verification/fixtures/` (auth token redacted). Captured & validated against test event 437.
- **Golden-master fixtures from the OLD Obj-C code** — exact submit payloads and parsed model values for sample inputs (generated via a small dump routine in the existing test target), so "matches old behavior" is a hard assertion.
- **Test account** (user-provided, throwaway; real events not live so writes are safe): event "Test Lonesome 100" (id 437), submit to any split (e.g. Raspberry 1). Credentials in local memory, not committed.

## Autonomy & human checkpoint

- Runs unattended; proceeds screen-by-screen without per-screen human approval; commit per screen as gates pass.
- Requires an auto-approving permission mode / allowlist (xcodebuild, git, file edits) so it does not stall on prompts.
- A **1-hour resume loop** wakes work if it halts (e.g., token/usage limits) so it continues when limits refresh.
- **One human checkpoint** after the bulk is done (through Review/Sync): a simulator/device build + a short manual checklist + before/after screenshots for a real-device pass.

## Risks & mitigations

- **Subtle sync/cross-check regressions** → golden-master assertions + live test-event submits.
- **APNumberPad / Cross Check grid fidelity** → reproduced as isolated components with snapshot/behavior tests.
- **Token expiry mid-run** → APIClient re-auth from stored credentials.
- **Unattended stalls on permission prompts** → auto-approve mode (prerequisite).
- **CoreData store coexistence (MagicalRecord + NSPersistentContainer)** → same model file, same store URL, single coordinator; verified by CoreData tests early.
