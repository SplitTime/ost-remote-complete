# Logout network check — design

**Date:** 2026-06-20
**Branch:** swiftui-rewrite
**Status:** Approved, ready for plan

## Problem

Tapping **Logout** in Utilities always reports "Logout is disabled — please try
again when you have an Internet connection" on the first tap, even when online.
A second tap then works. There is no real network verification happening.

### Root cause

`OSTUtilitiesViewController.onLogout` guards on
`app.getNetworkManager().isReachable`, which reads
`OSTReachability.shared.isReachable` →
`monitor.currentPath.status == .satisfied` (`OSTReachability.swift:19`).

`NWPathMonitor` starts in an `.unsatisfied`/`.requiresConnection` state and only
transitions to `.satisfied` after its first asynchronous path update is
delivered on its background queue. So the first read after `start()` is almost
always `false` → "disabled". By the second tap the monitor has caught up and
reports `true`. The check is effectively a meaningless double-tap.

## Goal

Replace the passive reachability read with an **active backend check** that runs
when the user taps Logout:

- **200** → proceed to logout (with the existing "Are you sure?" confirmation).
- **Non-200 / any failure** → block logout but offer an immediate **override**.

Also remove the now-dead reachability plumbing.

## Decisions (from brainstorming)

- **Check target:** the existing authenticated **autoLogin** (POST `auth` with
  stored credentials). A 200 proves both that the server is reachable *and* that
  the saved credentials still work — i.e. the user can actually log back in,
  which is exactly what the logout warning promises.
- **Override behavior:** the failure alert *is* the confirmation. Its
  destructive "Log Out Anyway" button logs out immediately (no second prompt).
- **Checking UX:** show a "Checking connection…" spinner overlay while the
  autoLogin round-trip is in flight; dismiss it when the result returns.

## Flow

```
Tap Logout
  → present "Checking connection…" spinner overlay (no buttons)
  → OSTBackend.shared.verifyConnection (autoLogin: POST auth w/ stored creds)
       ├─ 200  → dismiss spinner → "Are you sure?" confirm
       │             → Logout → toggle menu + app.logout()
       └─ fail → dismiss spinner → failure alert "Can't reach OpenSplitTime":
                    "Log Out Anyway" (.destructive) → toggle menu + app.logout()
                    "Cancel"
```

The modal spinner blocks repeat taps while the check is in flight, so the old
double-tap problem cannot recur.

## Components

### 1. `OSTBackend.swift` — new public check

Expose the existing `private autoLogin` via a small wrapper that delivers its
result on the main queue:

```swift
/// Active connectivity + credential check used before logout.
/// `nil` == reachable and stored credentials valid (200); non-nil == blocked.
func verifyConnection(completion: @escaping (Error?) -> Void) {
    autoLogin { error in DispatchQueue.main.async { completion(error) } }
}
```

No new networking — reuses the same `autoLogin` the read endpoints already use.
`autoLogin` already returns a clean 401 error when stored credentials are
missing or rejected, which routes to the override path.

### 2. `OSTUtilitiesViewController.onLogout` — rewrite (`OSTUtilitiesViewController.swift:162`)

Replace the entire `isReachable == false` block. New sequence:

1. Present a no-button `UIAlertController` titled "Checking connection…" with a
   `UIActivityIndicatorView` added as a subview (standard iOS 12 spinner-in-
   alert pattern).
2. Call `OSTBackend.shared.verifyConnection`.
3. In the completion (main queue), dismiss the spinner, then present the next
   alert inside the spinner's `dismiss(animated:completion:)` completion block
   (chained so we never present-while-presenting):
   - **success** → existing "Are you sure you would like to log out?" confirm
     (Cancel + destructive Logout). Logout action: `toggleRightSideMenuCompletion`
     + `app.logout()`.
   - **failure** → alert titled "Can't reach OpenSplitTime", message keeps the
     existing warning copy ("You will not be able to log back in or add entries
     until you have a data connection again."). Actions: **Log Out Anyway**
     (`.destructive` → toggle menu + `app.logout()`) and **Cancel**.

### 3. Dead-code removal

`OSTReachability` and `OSTNetworkManager`'s reachability surface have no
remaining readers after the rewrite (the logout guard was the only one). Remove:

- **`OST Tracker/Swift/OSTReachability.swift`** — delete the whole file, and
  remove its file reference / build-phase membership from the Xcode project
  (`OST Tracker.xcodeproj/project.pbxproj`).
- **`OSTNetworkManager.h`** — remove the `isReachable` property (line 45) and the
  `- (void)startMonitoring;` declaration (line 48).
- **`OSTNetworkManager.m`** — remove the generated-Swift-header import block
  (lines 10–15, present only for `OSTReachability`), the `[self startMonitoring]`
  call in `init` (line 25), the `startMonitoring` method (35–38), and the
  `isReachable` method (40–43).
- **`AppDelegate.m`** — remove the `[self.networkManager startMonitoring]` call
  in `getNetworkManager` (line 51).

## Error handling

Any non-200 outcome — no network, server unreachable, or rejected credentials —
resolves to the same failure/override alert. Causes are not differentiated
(per the "if not 200, offer override" decision); one warning covers all.

## Testing

UIKit alert flow against live network state → manual verification on
simulator/device:

- **Online:** tap Logout → spinner → "Are you sure?" → logs out. No spurious
  "disabled" on the first tap.
- **Airplane mode:** tap Logout → spinner → "Can't reach OpenSplitTime" →
  "Log Out Anyway" logs out; "Cancel" stays on the screen.
- **Build:** project builds from `OST Tracker.xcodeproj` directly with
  `OSTReachability.swift` removed (no dangling references in `project.pbxproj`).
