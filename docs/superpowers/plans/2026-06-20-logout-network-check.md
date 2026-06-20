# Logout Network Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken passive reachability guard on logout with an active authenticated backend check, and remove the now-dead reachability plumbing.

**Architecture:** Tapping Logout presents a "Checking connection…" spinner and calls the existing `autoLogin` (POST `auth` with stored credentials) through a new `OSTBackend.verifyConnection` wrapper. A 200 proceeds to the normal "Are you sure?" confirmation; any failure shows an override alert whose "Log Out Anyway" button logs out immediately. The `NWPathMonitor`-based `OSTReachability` and `OSTNetworkManager`'s reachability surface are then deleted since the logout guard was their only reader.

**Tech Stack:** Swift + Objective-C, UIKit (iOS 12 floor), URLSession via `APIClient`. Built directly from `OST Tracker.xcodeproj` (zero CocoaPods).

## Global Constraints

- **iOS 12 floor** — no async/await; no iOS 13+ APIs. Use `UIActivityIndicatorView(style: .gray)` (NOT `.medium`).
- **Build from the project directly** — no workspace, no pods. Scheme: `OST Remote`.
- **Two app targets** — `OST Remote` and `OST Remote Dev` both compile the touched files; pbxproj edits must keep both targets consistent.
- **DRY** — the logout action (toggle menu + `logout()`) is shared by the confirm and override paths via a single helper, not duplicated.
- **Verification is manual** — this is a UIKit alert flow against live network state; there is no cheap unit test. The test cycle per task is: clean build green + the manual simulator checks listed in the task. (Per the spec's Testing section.)
- **Exact copy:**
  - Spinner title: `Checking connection…`
  - Confirm title: `Are you sure you would like to log out?`
  - Override title: `Can't reach OpenSplitTime`
  - Shared warning message: `You will not be able to log back in or add entries until you have a data connection again.`
  - Override destructive button: `Log Out Anyway`; confirm destructive button: `Logout`.

**Build command (used as the verification gate in every task):**
```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -sdk iphonesimulator -configuration Debug build 2>&1 | tail -3
```
Expected: a line containing `** BUILD SUCCEEDED **`.

---

## File Structure

- `OST Tracker/Swift/OSTBackend.swift` — **modify**: add `verifyConnection(completion:)` exposing the existing private `autoLogin` on the main queue.
- `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift` — **modify**: rewrite `onLogout`; add `performLogout`, `presentLogoutConfirmation`, `presentLogoutOverride` helpers.
- `OST Tracker/Swift/OSTReachability.swift` — **delete**.
- `OST Tracker.xcodeproj/project.pbxproj` — **modify**: remove all 6 `OSTReachability.swift` references.
- `OST Tracker/Network/OSTNetworkManager.h` — **modify**: drop `isReachable` property + `startMonitoring` declaration.
- `OST Tracker/Network/OSTNetworkManager.m` — **modify**: drop Swift-header import block, `startMonitoring` call/impl, `isReachable` impl.
- `OST Tracker/AppDelegate.m` — **modify**: drop the `startMonitoring` call in `getNetworkManager`.

---

## Task 1: Add `OSTBackend.verifyConnection`

**Files:**
- Modify: `OST Tracker/Swift/OSTBackend.swift` (add method after the `autoLogin` private method, ~line 114)

**Interfaces:**
- Consumes: existing `private func autoLogin(_ completion: @escaping (Error?) -> Void)` in the same file.
- Produces: `func verifyConnection(completion: @escaping (Error?) -> Void)` — `nil` == reachable + stored credentials valid (200); non-nil Error == blocked. Completion is delivered on the **main queue**.

- [ ] **Step 1: Add the method**

In `OST Tracker/Swift/OSTBackend.swift`, immediately above the `// MARK: - Plumbing` line (before `private func request`), add:

```swift
    // MARK: - Pre-logout connectivity check

    /// Active connectivity + credential check used before logout. Runs the same
    /// `autoLogin` (POST `auth` with stored credentials) the read endpoints use.
    /// `nil` == reachable and credentials valid (200); non-nil == blocked.
    /// Completion is delivered on the main queue.
    @objc func verifyConnection(completion: @escaping (Error?) -> Void) {
        autoLogin { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run the Global Constraints build command.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
git add "OST Tracker/Swift/OSTBackend.swift" && \
git commit -m "OSTBackend: add verifyConnection (autoLogin check for pre-logout)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Rewrite `onLogout` with active check + spinner + override

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift:162-181` (replace the entire `onLogout` method, add three helpers)

**Interfaces:**
- Consumes: `OSTBackend.shared.verifyConnection(completion:)` from Task 1; `AppDelegate.getInstance()`, `app.rightMenuVC.toggleRightSideMenuCompletion(_:)`, `app.logout()` (existing).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Replace `onLogout` and add helpers**

Replace the whole method at `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift:162-181`:

```swift
    @IBAction func onLogout(_ sender: Any) {
        let checking = UIAlertController(title: "Checking connection…",
                                         message: "\n\n",
                                         preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .gray)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        checking.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: checking.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: checking.view.bottomAnchor, constant: -16)
        ])
        present(checking, animated: true)

        OSTBackend.shared.verifyConnection { [weak self] error in
            guard let self = self else { return }
            checking.dismiss(animated: true) {
                if error == nil {
                    self.presentLogoutConfirmation()
                } else {
                    self.presentLogoutOverride()
                }
            }
        }
    }

    /// Online: confirm, then log out.
    private func presentLogoutConfirmation() {
        let alert = UIAlertController(title: "Are you sure you would like to log out?",
                                      message: "You will not be able to log back in or add entries until you have a data connection again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    /// Check failed: block, but allow an immediate override.
    private func presentLogoutOverride() {
        let alert = UIAlertController(title: "Can't reach OpenSplitTime",
                                      message: "You will not be able to log back in or add entries until you have a data connection again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out Anyway", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    private func performLogout() {
        let app = AppDelegate.getInstance()
        app?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        app?.logout()
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run the Global Constraints build command.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual verification — online happy path**

Run the app on a simulator with network. Open the right menu → Utilities → tap **Logout**.
Expected: brief "Checking connection…" spinner → "Are you sure you would like to log out?" appears on the FIRST tap (no "disabled" message). "Logout" logs out; "Cancel" dismisses.

- [ ] **Step 4: Manual verification — offline override path**

Enable Airplane Mode (or stop the backend). Tap **Logout**.
Expected: spinner → "Can't reach OpenSplitTime" with "Log Out Anyway" (logs out) and "Cancel" (stays). Repeat-tapping during the spinner does nothing (modal blocks it).

- [ ] **Step 5: Commit**

```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
git add "OST Tracker/ViewControllers/OSTUtilitiesViewController.swift" && \
git commit -m "Logout: active backend check with spinner + override

Replaces the NWPathMonitor guard that always read 'disabled' on first
tap. verifyConnection (autoLogin) gates the confirm; failure offers an
immediate Log Out Anyway override.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Remove dead reachability plumbing

**Files:**
- Delete: `OST Tracker/Swift/OSTReachability.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (remove 6 `OSTReachability.swift` lines)
- Modify: `OST Tracker/Network/OSTNetworkManager.h` (remove `isReachable` property line 45, `startMonitoring` declaration line 48)
- Modify: `OST Tracker/Network/OSTNetworkManager.m` (remove Swift-header import block lines 10-15, `[self startMonitoring]` in init line 25, `startMonitoring` impl lines 35-38, `isReachable` impl lines 40-43)
- Modify: `OST Tracker/AppDelegate.m` (remove `[self.networkManager startMonitoring]` line 51)

**Interfaces:**
- Consumes: nothing. This task only removes code with no remaining readers (verified: the logout guard removed in Task 2 was the sole `isReachable` reader).
- Produces: nothing.

- [ ] **Step 1: Confirm there are no remaining readers**

```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
grep -rn "isReachable\|startMonitoring\|OSTReachability" "OST Tracker/" | grep -v xcodeproj
```
Expected: only the *definition/declaration* lines in `OSTNetworkManager.h`, `OSTNetworkManager.m`, and `OSTReachability.swift` — NO references in `OSTUtilitiesViewController.swift` or anywhere else. (If a non-definition reader appears, stop and reassess.)

- [ ] **Step 2: Delete the Swift file**

```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
git rm "OST Tracker/Swift/OSTReachability.swift"
```

- [ ] **Step 3: Remove the 6 pbxproj references**

```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
sed -i '' '/OSTReachability/d' "OST Tracker.xcodeproj/project.pbxproj" && \
grep -c "OSTReachability" "OST Tracker.xcodeproj/project.pbxproj"
```
Expected: `0`. (Each `OSTReachability.swift` reference is a self-contained single line — build file, file reference, group child, and sources entries for both targets.)

- [ ] **Step 4: Edit `OSTNetworkManager.h`**

Remove this line:
```objc
@property (nonatomic,readonly) BOOL isReachable;
```
And this line:
```objc
- (void)startMonitoring;
```

- [ ] **Step 5: Edit `OSTNetworkManager.m`**

Remove the Swift-header import block (it existed only for `OSTReachability`):
```objc
// Generated Swift header — for OSTReachability. Module name differs per target.
#if __has_include("OST_Remote-Swift.h")
#import "OST_Remote-Swift.h"
#elif __has_include("OST_Remote_Dev-Swift.h")
#import "OST_Remote_Dev-Swift.h"
#endif
```
Remove the call in `init`:
```objc
        [self startMonitoring];
```
Remove the two methods:
```objc
- (void)startMonitoring
{
    [[OSTReachability shared] start];
}

- (BOOL)isReachable
{
    return [OSTReachability shared].isReachable;
}
```
After this edit, `OSTNetworkManager.m`'s `init` keeps only the `self.serviceURL = ...` assignment, and the file imports only `OSTNetworkManager.h`.

- [ ] **Step 6: Edit `AppDelegate.m`**

In `getNetworkManager`, remove this line:
```objc
        [self.networkManager startMonitoring];
```
(Leave the surrounding `if (self.networkManager == nil) { self.networkManager = [[OSTNetworkManager alloc] init]; }` intact — `init` no longer monitors, which is fine.)

- [ ] **Step 7: Build to verify nothing dangles**

Run the Global Constraints build command.
Expected: `** BUILD SUCCEEDED **` (no "cannot find OSTReachability", no missing-file errors from pbxproj).

- [ ] **Step 8: Manual re-verification — both paths still work**

Re-run Task 2 Steps 3 and 4 (online happy path + offline override) to confirm the removal didn't regress logout.
Expected: identical behavior to Task 2.

- [ ] **Step 9: Commit**

```bash
cd "/Users/joneisen/dev/SplitTime/ost-remote-complete" && \
git add -A && \
git commit -m "Remove dead NWPathMonitor reachability plumbing

OSTReachability + OSTNetworkManager.isReachable/startMonitoring had no
readers after the logout check moved to an active autoLogin call.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Root-cause fix (active check replacing NWPathMonitor first-read) → Task 2.
- Check target = authenticated autoLogin → Task 1 (`verifyConnection` wraps `autoLogin`).
- Override = log out now → Task 2 `presentLogoutOverride` (destructive button calls `performLogout` directly).
- Spinner overlay while checking → Task 2 Step 1.
- Failure title "Can't reach OpenSplitTime" + shared warning copy → Task 2, Global Constraints.
- Dead-code removal (file + pbxproj + .h + .m + AppDelegate) → Task 3.
- Manual testing (online + airplane + clean build) → Task 2 Steps 3-4, Task 3 Steps 7-8.

All spec sections map to a task. No gaps.

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step shows complete code.

**Type consistency:** `verifyConnection(completion: @escaping (Error?) -> Void)` defined in Task 1, called identically in Task 2. `performLogout` / `presentLogoutConfirmation` / `presentLogoutOverride` names consistent throughout Task 2.
