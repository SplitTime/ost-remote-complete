# Login Screen (Swift + UIKit, iOS 12) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Execute inline (no subagents). Steps use `- [ ]`.

**Goal:** Replace `OSTLoginViewController` (Obj-C/XIB) with a Swift + UIKit login screen (iOS 12, Modern-iOS style, safe-area correct) that authenticates via the new `APIClient`, stores credentials in `OSTSessionManager`, sets the bearer token, and presents the existing `OSTEventSelectionViewController` on success.

**Architecture:** A testable `LoginController` (logic) depends on an `Authenticating` protocol (APIClient conforms) and a `CredentialStore` protocol (OSTSessionManager-backed). `LoginViewController` is a thin programmatic UIKit view driving `LoginController`. Wire it in as the app's initial screen in place of the Obj-C login.

**Tech Stack:** Swift, UIKit, URLSession (completion handlers), XCTest. iOS 12 only.

---

## Behavior to preserve (from OSTLoginViewController.m)
- Prefill email/password from `OSTSessionManager.getStoredUserName/getStoredPassword`.
- On login: `APIClient.login` → on success set bearer token + `OSTSessionManager.setUserName:andPassword:`, then present `OSTEventSelectionViewController` (full screen). On failure: show an alert.

---

## Task 1: Auth + credential-store protocols, APIClient conformance

**Files:** Create `OST Tracker/Swift/LoginController.swift`; Test `OST TrackerTests/Swift/LoginControllerTests.swift`

- [ ] **Step 1: Failing test** — `LoginController` calls auth, stores creds on success, reports `.success`; on auth failure does NOT store creds and reports `.failure`. Use a stub `Authenticating` + spy `CredentialStore`.

```swift
import XCTest
@testable import OST_Remote

private final class StubAuth: Authenticating {
    var result: Result<AuthResponse, Error>!
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) { completion(result) }
}
private final class SpyStore: CredentialStore {
    var saved: (String, String)?
    var email: String?; var password: String?
    func save(email: String, password: String) { saved = (email, password) }
}

final class LoginControllerTests: XCTestCase {
    func test_success_storesCredentials() {
        let auth = StubAuth(); auth.result = .success(AuthResponse(token: "t", expiration: nil))
        let store = SpyStore()
        let sut = LoginController(auth: auth, store: store)
        let exp = expectation(description: "x")
        sut.login(email: "a@b.com", password: "pw") { result in
            if case .success = result {} else { XCTFail() }; exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(store.saved?.0, "a@b.com"); XCTAssertEqual(store.saved?.1, "pw")
    }
    func test_failure_doesNotStore() {
        let auth = StubAuth(); auth.result = .failure(URLError(.userAuthenticationRequired))
        let store = SpyStore()
        let sut = LoginController(auth: auth, store: store)
        let exp = expectation(description: "x")
        sut.login(email: "a@b.com", password: "pw") { result in
            if case .failure = result {} else { XCTFail() }; exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertNil(store.saved)
    }
}
```

- [ ] **Step 2: Run, verify fails** (types undefined).
- [ ] **Step 3: Implement protocols + LoginController + APIClient conformance**

```swift
import Foundation

protocol Authenticating {
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void)
}
extension APIClient: Authenticating {
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        _ = login(email: email, password: password, completion: completion) // calls the @discardableResult method
    }
}

protocol CredentialStore {
    func save(email: String, password: String)
    var email: String? { get }
    var password: String? { get }
}

final class LoginController {
    private let auth: Authenticating
    private let store: CredentialStore
    init(auth: Authenticating, store: CredentialStore) { self.auth = auth; self.store = store }

    func login(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        auth.login(email: email, password: password) { [store] result in
            switch result {
            case .success:
                store.save(email: email, password: password)
                completion(.success(()))
            case .failure(let e):
                completion(.failure(e))
            }
        }
    }
}
```

Note: the `extension APIClient: Authenticating` may collide with the existing `login` signature — if so, rename the protocol method to `authenticate(email:password:completion:)` and have the extension forward to `login`. Resolve at implementation time.

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** `git commit -m "Login Task1: LoginController + Authenticating/CredentialStore protocols"`

## Task 2: OSTSessionManager-backed CredentialStore

**Files:** add `SessionCredentialStore` to `LoginController.swift`; Test in `LoginControllerTests.swift`.

- [ ] **Step 1:** Implement, bridging to Obj-C `OSTSessionManager`:

```swift
final class SessionCredentialStore: CredentialStore {
    func save(email: String, password: String) { OSTSessionManager.setUserName(email, andPassword: password) }
    var email: String? { OSTSessionManager.getStoredUserName() }
    var password: String? { OSTSessionManager.getStoredPassword() }
}
```
Add `#import "OSTSessionManager.h"` to the bridging header.

- [ ] **Step 2:** Build (no new behavioral test — it's a thin bridge). Verify `OST Remote` builds.
- [ ] **Step 3: Commit.**

## Task 3: LoginViewController (Swift/UIKit, programmatic, safe-area, Modern iOS)

**Files:** Create `OST Tracker/Swift/LoginViewController.swift`

- [ ] **Step 1:** Build the screen programmatically: centered logo, "OST Remote" title, email + password fields (rounded, `textContentType`, secure for password), a prominent login button, all inside a vertical stack pinned to `view.safeAreaLayoutGuide` with horizontal padding. Prefill from the store. Slightly higher than center per the old look but respect safe area (user noted old login sat "a bit high" — center it cleanly).
- [ ] **Step 2:** On tap: disable button + show spinner, call `LoginController.login`; on success present `OSTEventSelectionViewController` (`modalPresentationStyle = .fullScreen`); on failure show `UIAlertController`. (Bridge `OSTEventSelectionViewController` via header.)
- [ ] **Step 3:** Build `OST Remote`; verify green.
- [ ] **Step 4: Commit.**

## Task 4: Wire into the app in place of the Obj-C login

**Files:** Modify `OST Tracker/AppDelegate.m` (the place that sets the login as root / initial VC).

- [ ] **Step 1:** Find where `OSTLoginViewController` is instantiated as the initial screen; replace with `LoginViewController` (Swift class is visible to Obj-C via the generated `OST_Remote-Swift.h`; mark `LoginViewController` `@objc` / `public` as needed). Keep the same presentation.
- [ ] **Step 2:** Build `OST Remote`; verify green.
- [ ] **Step 3: Commit.**

## Task 5: Verify on simulator (behavior + safe area)

- [ ] **Step 1:** Boot iPhone 17 sim, install, launch; screenshot the login screen. Assert visually: content clear of the Dynamic Island, fields/button laid out, not "too high".
- [ ] **Step 2:** Log in with the test account (`tracking@freestoneendurance.com` / `hilo2022`); confirm it reaches the event-selection screen (same as old app). Screenshot.
- [ ] **Step 3:** Capture before/after screenshots into `Verification/screenshots/` for the human checkpoint.
- [ ] **Step 4: Commit** any screenshot artifacts + a note.

---

## Self-review
- Preserves: prefill, auth call, credential storage, token set, navigation to event selection. ✓
- iOS 12 only (no SwiftUI/async). ✓
- Safe-area correct (pinned to safeAreaLayoutGuide). ✓
- Token set: ensure the shared network manager / APIClient has the bearer token after login (old code did `addTokenToHeader`). The Swift `APIClient` stores its own token; the OLD `OSTEventSelectionViewController` still uses the Obj-C `OSTNetworkManager`, so **after login also call `[[AppDelegate getInstance].getNetworkManager addTokenToHeader:token]`** (bridge) until event-selection is migrated. Add this in Task 3 Step 2.
