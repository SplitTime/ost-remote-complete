import XCTest
@testable import OST_Remote

final class AutoSyncControllerTests: XCTestCase {
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
