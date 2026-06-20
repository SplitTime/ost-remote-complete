import XCTest
@testable import OST_Remote

final class AutoSyncControllerTests: XCTestCase {
    /// Snapshot of the shared CoreData stack, restored in tearDown so these tests
    /// don't permanently displace the on-disk store for other test classes.
    private var savedStack: CoreDataStack!

    override func setUp() {
        super.setUp()
        // Swap in an in-memory store so fetchPending() returns [] even when the
        // controller is briefly enabled. This prevents setEnabled(true) →
        // attemptSync() from reaching runSync with live production-store entries.
        savedStack = CoreDataStack.shared
        CoreDataStack.shared = CoreDataStack(inMemory: true)
        AutoSyncController.shared.autoSyncEnabled = false
    }

    override func tearDown() {
        AutoSyncController.shared.autoSyncEnabled = false
        CoreDataStack.shared = savedStack
        savedStack = nil
        super.tearDown()
    }

    func test_autoSyncEnabled_defaultsOff_andPersists() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "OSTAutoSyncEnabled")
        XCTAssertFalse(AutoSyncController.shared.autoSyncEnabled, "default OFF on first run")
        AutoSyncController.shared.autoSyncEnabled = true
        XCTAssertTrue(defaults.bool(forKey: "OSTAutoSyncEnabled"))
        AutoSyncController.shared.autoSyncEnabled = false // restore
    }

    func test_togglingEnabled_postsStatusChanged() {
        let exp = expectation(forNotification: AutoSyncController.statusChangedNotification, object: nil, handler: nil)
        AutoSyncController.shared.autoSyncEnabled = true
        wait(for: [exp], timeout: 1)
        AutoSyncController.shared.autoSyncEnabled = false
    }
}
