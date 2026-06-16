# OST Remote SwiftUI Rewrite — Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do NOT spawn subagents (user has not requested them); execute inline.

**Goal:** Establish the Swift/SwiftUI substrate — Swift enabled in the mixed target, a `NSPersistentContainer` CoreData stack over the existing model, a `URLSession` `APIClient` reproducing the OpenSplitTime contract, and an automated verification harness — all with no UI change and the app still building/running.

**Architecture:** Add Swift to the existing Obj-C app target via a bridging header. New Swift services (CoreDataStack, APIClient, SyncService) live alongside the Obj-C code and are unit-tested against recorded fixtures in `Verification/fixtures/` plus golden-master output from the old Obj-C code. Nothing in the Obj-C app is removed yet.

**Tech Stack:** Swift 5+, SwiftUI (later milestones), URLSession + async/await, CoreData (`NSPersistentContainer`), XCTest. New deps via SPM only.

---

## File Structure

- `OST Tracker/Swift/` — new Swift sources
  - `CoreDataStack.swift` — `NSPersistentContainer` over `OSTDataModel`, same sqlite store as MagicalRecord
  - `APIClient.swift` — URLSession client, base URL, bearer auth, async endpoints
  - `APIModels.swift` — Codable models for auth + JSON:API responses
  - `LiveTimeEntry.swift` — value type + submit-payload builder (matches old Obj-C exactly)
  - `SyncService.swift` — batch-300 + alternate-server fallback logic
- `OST Tracker/OST Tracker-Bridging-Header.h` — exposes Obj-C (EntryModel, CurrentCourse, OSTConstants) to Swift
- `OST TrackerTests/Swift/` — new test sources
  - `APIParsingTests.swift`, `SubmitPayloadGoldenTests.swift`, `SyncServiceTests.swift`, `CoreDataStackTests.swift`
  - `FixtureLoader.swift` — loads JSON from `Verification/fixtures/`

---

## Task 1: Enable Swift in the app + test targets

**Files:**
- Create: `OST Tracker/OST Tracker-Bridging-Header.h`
- Create: `OST Tracker/Swift/SwiftSmoke.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (build settings; via Xcode-safe edits)

- [ ] **Step 1: Read the current Swift/constants state**

Run: `grep -n "SWIFT_VERSION\|OSTCoredataFile" "OST Tracker/OSTConstants.h" "OST Tracker.xcodeproj/project.pbxproj"`
Expected: `SWIFT_VERSION = 3.0` in configs; find the `OSTCoredataFile` string value in `OSTConstants.h`. Record the sqlite filename for Task 2.

- [ ] **Step 2: Add a bridging header exposing the Obj-C we need from Swift**

Create `OST Tracker/OST Tracker-Bridging-Header.h`:

```objc
#import "EntryModel.h"
#import "CurrentCourse.h"
#import "EventModel.h"
#import "EffortModel.h"
#import "CourseSplits.h"
#import "OSTConstants.h"
```

- [ ] **Step 3: Add a trivial Swift file so the toolchain compiles Swift**

Create `OST Tracker/Swift/SwiftSmoke.swift`:

```swift
import Foundation

/// Forces the Swift toolchain on; replaced as real Swift code lands.
@objc final class SwiftSmoke: NSObject {
    @objc static func ping() -> String { "swift-ok" }
}
```

- [ ] **Step 4: Set build settings (both `OST Remote` and `OST Remote Dev` + test target)**

Set in project.pbxproj for app + test configs:
- `SWIFT_VERSION = 5.0`
- `SWIFT_OBJC_BRIDGING_HEADER = "OST Tracker/OST Tracker-Bridging-Header.h"` (app target only)
- `CLANG_ENABLE_MODULES = YES`

Use Xcode's `xcodebuild -showBuildSettings` to confirm, or edit pbxproj directly. Add the two new files to the `OST Remote`, `OST Remote Dev`, and (SwiftSmoke only) test target membership.

- [ ] **Step 5: Build to verify Swift compiles and bridging resolves**

Run: `xcodebuild -workspace "OST Tracker.xcworkspace" -scheme "OST Remote" -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Enable Swift in target with bridging header (foundations)"
```

---

## Task 2: CoreDataStack over the existing model + same store

**Files:**
- Create: `OST Tracker/Swift/CoreDataStack.swift`
- Test: `OST TrackerTests/Swift/CoreDataStackTests.swift`, `OST TrackerTests/Swift/FixtureLoader.swift`

- [ ] **Step 1: Write the failing test**

`CoreDataStackTests.swift`:

```swift
import XCTest
import CoreData
@testable import OST_Remote   // adjust module name to match target

final class CoreDataStackTests: XCTestCase {
    func test_loadsExistingModel_andRoundTripsEntry() throws {
        let stack = CoreDataStack(inMemory: true)
        let ctx = stack.viewContext
        let entry = NSEntityDescription.insertNewObject(forEntityName: "EntryModel", into: ctx)
        entry.setValue("123", forKey: "bibNumber")
        try ctx.save()

        let req = NSFetchRequest<NSManagedObject>(entityName: "EntryModel")
        let found = try ctx.fetch(req)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.value(forKey: "bibNumber") as? String, "123")
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `xcodebuild test -workspace "OST Tracker.xcworkspace" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"OST TrackerTests/CoreDataStackTests" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: FAIL — `CoreDataStack` undefined.

- [ ] **Step 3: Implement CoreDataStack**

`CoreDataStack.swift`:

```swift
import CoreData

final class CoreDataStack {
    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }

    /// `inMemory` for tests. Production uses the same sqlite file MagicalRecord
    /// created (Application Support / <OSTCoredataFile>), so existing data is preserved.
    init(inMemory: Bool = false, storeName: String = "OSTCoredataFile.sqlite") {
        // Model name is "OSTDataModel" (OSTDataModel.xcdatamodeld).
        guard let modelURL = Bundle.main.url(forResource: "OSTDataModel", withExtension: "momd")
                ?? Bundle(for: CoreDataStack.self).url(forResource: "OSTDataModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("OSTDataModel not found")
        }
        container = NSPersistentContainer(name: "OSTDataModel", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let desc = NSPersistentStoreDescription(url: appSupport.appendingPathComponent(storeName))
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("CoreData load failed: \(error)") }
        }
    }
}
```

Note: confirm the exact `storeName` from `OSTCoredataFile` (Task 1 Step 1) and the `.momd` resource name; adjust if the model file differs.

- [ ] **Step 4: Run test, verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add NSPersistentContainer CoreDataStack over existing model"
```

---

## Task 3: APIClient + auth (live + fixture)

**Files:**
- Create: `OST Tracker/Swift/APIClient.swift`, `OST Tracker/Swift/APIModels.swift`
- Test: `OST TrackerTests/Swift/APIParsingTests.swift`

- [ ] **Step 1: Write failing parse test for auth + event list using fixtures**

`FixtureLoader.swift`:

```swift
import Foundation
enum Fixture {
    static func data(_ name: String) -> Data {
        // Verification/fixtures is added as a folder reference to the test target.
        let url = Bundle(for: CoreDataStackTests.self)
            .url(forResource: name, withExtension: "json", subdirectory: "fixtures")!
        return try! Data(contentsOf: url)
    }
}
```

`APIParsingTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class APIParsingTests: XCTestCase {
    func test_parsesEventGroupsList() throws {
        let list = try JSONDecoder().decode(JSONAPIList.self, from: Fixture.data("event_groups_list"))
        let names = list.data.map { $0.attributes.name }
        XCTAssertTrue(names.contains("Test Lonesome 100"))
    }
    func test_parsesEventGroupSplits() throws {
        let grp = try JSONDecoder().decode(JSONAPIDoc.self, from: Fixture.data("event_group_437"))
        let splits = grp.included.filter { $0.type == "splits" }.compactMap { $0.attributes.baseName }
        XCTAssertTrue(splits.contains("Raspberry 1"))
    }
}
```

- [ ] **Step 2: Run, verify it fails** (types undefined).

Run: `xcodebuild test -workspace "OST Tracker.xcworkspace" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"OST TrackerTests/APIParsingTests" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15`
Expected: FAIL.

- [ ] **Step 3: Implement Codable models matching the fixtures**

`APIModels.swift` (verify field presence against `Verification/fixtures/*.json`):

```swift
import Foundation

struct AuthResponse: Decodable { let token: String; let expiration: String? }

struct JSONAPIAttributes: Decodable {
    let name: String?         // event_groups
    let baseName: String?     // splits
    let fullName: String?     // efforts
    let bibNumber: Int?
}
struct JSONAPIResource: Decodable {
    let id: String
    let type: String
    let attributes: JSONAPIAttributes
}
struct JSONAPIList: Decodable { let data: [JSONAPIResource] }
struct JSONAPIDoc: Decodable {
    let data: JSONAPIResource
    let included: [JSONAPIResource]
    enum CodingKeys: String, CodingKey { case data, included }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        data = try c.decode(JSONAPIResource.self, forKey: .data)
        included = (try? c.decode([JSONAPIResource].self, forKey: .included)) ?? []
    }
}
```

- [ ] **Step 4: Implement APIClient skeleton (used live in later tasks)**

`APIClient.swift`:

```swift
import Foundation

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private var token: String?
    init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }

    func login(email: String, password: String) async throws -> AuthResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let body = "user[email]=\(email.formEncoded)&user[password]=\(password.formEncoded)"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
        token = auth.token
        return auth
    }

    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        if let token { req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private extension String {
    var formEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}
```

- [ ] **Step 5: Run parse tests, verify pass.** (Live login covered in Task 5.)

Run: same as Step 2. Expected: PASS. If a field name mismatches the fixture, fix `APIModels` to match the real JSON and re-run.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add APIClient + Codable models, parse-verified against fixtures"
```

---

## Task 4: Submit-payload golden master (matches old Obj-C exactly)

**Files:**
- Create: `OST Tracker/Swift/LiveTimeEntry.swift`
- Test: `OST TrackerTests/Swift/SubmitPayloadGoldenTests.swift`

- [ ] **Step 1: Capture the golden master from the OLD code**

The old `submitEntries:toEvent:` builds, per entry:
`{"type":"live_time","attributes":{bibNumber, splitId, subSplitKind, enteredTime, withPacer, stoppedHere, source}}`
and wraps as `{"uniqueKey":["enteredTime","bitkey","bibNumber","source","withPacer","stoppedHere"], "data":[...]}`.
Write this exact expected JSON (for one sample entry) to `Verification/fixtures/submit_live_time_golden.json` by hand-deriving from `OSTNetworkManager+Entries.m:62-90` (already read). Use sample values: bibNumber="42", splitId="900", bitKey="in", absoluteTime="2026-06-16T10:14:22-06:00", withPacer=false, stoppedHere=false, source="ost-remote-ios".

- [ ] **Step 2: Write the failing test**

`SubmitPayloadGoldenTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class SubmitPayloadGoldenTests: XCTestCase {
    func test_liveTimePayloadMatchesGolden() throws {
        let entry = LiveTimeEntry(bibNumber: "42", splitId: "900", subSplitKind: "in",
                                  enteredTime: "2026-06-16T10:14:22-06:00",
                                  withPacer: false, stoppedHere: false, source: "ost-remote-ios")
        let built = LiveTimeEntry.eventImportPayload([entry])
        let golden = try JSONSerialization.jsonObject(with: Fixture.data("submit_live_time_golden")) as! NSDictionary
        XCTAssertEqual(built as NSDictionary, golden)
    }
}
```

- [ ] **Step 3: Run, verify fails.** Expected: FAIL (`LiveTimeEntry` undefined).

- [ ] **Step 4: Implement LiveTimeEntry + payload builder**

`LiveTimeEntry.swift`:

```swift
import Foundation

struct LiveTimeEntry {
    let bibNumber: String, splitId: String, subSplitKind: String
    let enteredTime: String
    let withPacer: Bool, stoppedHere: Bool, source: String

    var attributes: [String: Any] {
        ["bibNumber": bibNumber, "splitId": splitId, "subSplitKind": subSplitKind,
         "enteredTime": enteredTime, "withPacer": withPacer,
         "stoppedHere": stoppedHere, "source": source]
    }
    static func eventImportPayload(_ entries: [LiveTimeEntry]) -> [String: Any] {
        ["uniqueKey": ["enteredTime", "bitkey", "bibNumber", "source", "withPacer", "stoppedHere"],
         "data": entries.map { ["type": "live_time", "attributes": $0.attributes] }]
    }
}
```

- [ ] **Step 5: Run, verify pass.** If unequal, diff built vs golden and align key order/types (JSON dict comparison is order-insensitive; types must match — bools as bools).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Add live_time submit payload builder with golden-master test"
```

---

## Task 5: SyncService logic port (batch-300 + alternate-server fallback)

**Files:**
- Create: `OST Tracker/Swift/SyncService.swift`
- Test: `OST TrackerTests/Swift/SyncServiceTests.swift`

- [ ] **Step 1: Write failing tests with a mock submitter**

`SyncServiceTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class SyncServiceTests: XCTestCase {
    func test_batchesIn300sAndMarksSubmitted() async throws {
        var batchSizes: [Int] = []
        let svc = SyncService(submit: { batch, _ in batchSizes.append(batch.count) })
        try await svc.sync(entryCount: 650, useAlternate: false)
        XCTAssertEqual(batchSizes, [300, 300, 50])
    }
    func test_fallsBackToAlternateServerOnPrimaryFailure() async throws {
        var serversUsed: [Bool] = []
        let svc = SyncService(submit: { _, alt in
            serversUsed.append(alt)
            if !alt { throw URLError(.notConnectedToInternet) }
        })
        try await svc.sync(entryCount: 10, useAlternate: false)
        XCTAssertEqual(serversUsed, [false, true])
    }
}
```

- [ ] **Step 2: Run, verify fails.** Expected: FAIL.

- [ ] **Step 3: Implement SyncService**

`SyncService.swift`:

```swift
import Foundation

final class SyncService {
    /// Injected so tests don't hit the network. `(batchCount, useAlternate)`.
    private let submit: (_ batch: [Int], _ useAlternate: Bool) async throws -> Void
    init(submit: @escaping (_ batch: [Int], _ useAlternate: Bool) async throws -> Void) {
        self.submit = submit
    }

    /// Mirrors OSTSyncManager: try primary; on failure retry whole thing on alternate.
    func sync(entryCount: Int, useAlternate: Bool) async throws {
        do { try await submitAll(entryCount: entryCount, useAlternate: useAlternate) }
        catch {
            if !useAlternate { try await submitAll(entryCount: entryCount, useAlternate: true) }
            else { throw error }
        }
    }
    private func submitAll(entryCount: Int, useAlternate: Bool) async throws {
        var remaining = entryCount
        var offset = 0
        while remaining > 0 {
            let n = min(300, remaining)
            try await submit(Array(offset..<offset+n), useAlternate)
            remaining -= n; offset += n
        }
    }
}
```

Note: the real signature will take `[LiveTimeEntry]`; tests use `Int` counts as a stand-in for batching. Keep the production method generic over the entry array; this task proves the control flow.

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Port sync batching + alternate-server fallback with tests"
```

---

## Task 6: Live network smoke test (gated) + verification script

**Files:**
- Create: `Verification/run-verification.sh`
- Test: `OST TrackerTests/Swift/LiveAPITests.swift` (skipped unless `OST_LIVE_TESTS=1`)

- [ ] **Step 1: Write the gated live test**

`LiveAPITests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class LiveAPITests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["OST_LIVE_TESTS"] == "1")
    }
    func test_loginAndFetchEventGroup() async throws {
        let client = APIClient(baseURL: URL(string: "https://www.opensplittime.org/api/v1/")!)
        _ = try await client.login(email: ProcessInfo.processInfo.environment["OST_EMAIL"]!,
                                   password: ProcessInfo.processInfo.environment["OST_PASSWORD"]!)
        let grp: JSONAPIDoc = try await client.get("event_groups/437?include=events.efforts,events.splits", as: JSONAPIDoc.self)
        XCTAssertEqual(grp.data.id, "437")
    }
}
```

- [ ] **Step 2: Create the verification script**

`Verification/run-verification.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild test -workspace "OST Tracker.xcworkspace" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"OST TrackerTests" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -25
```
Make executable: `chmod +x Verification/run-verification.sh`.

- [ ] **Step 3: Run offline suite, verify green**

Run: `Verification/run-verification.sh`
Expected: `** TEST SUCCEEDED **` (live test skipped).

- [ ] **Step 4: Run the live test once manually (credentials from memory)**

Run with `OST_LIVE_TESTS=1 OST_EMAIL=... OST_PASSWORD=...` env. Expected: PASS against event 437. (Do not commit credentials.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "Add gated live API test + verification runner script"
```

---

## Self-Review Notes

- **Spec coverage:** Foundations = APIClient (✓ T3/T6), CoreData store (✓ T2), sync logic (✓ T5), golden-master submit (✓ T4), automated gate/script (✓ T6), Swift enablement (✓ T1). Safe-area smoke test + per-screen UI belong to the screen milestones, not Foundations.
- **Module name:** `@testable import OST_Remote` — confirm the actual product module name in Task 1 (`xcodebuild -showBuildSettings | grep PRODUCT_MODULE_NAME`) and adjust all test imports.
- **Fixtures in test bundle:** Task 3 assumes `Verification/fixtures` is added to the test target as a folder reference (blue folder). Add it during Task 3 Step 1 if missing.
- **Next milestone:** after green, write `docs/superpowers/plans/2026-06-16-login-screen.md` (Login screen in SwiftUI hosted via UIHostingController), then continue per the design doc.
```
