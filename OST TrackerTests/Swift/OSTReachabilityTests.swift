// OST TrackerTests/Swift/OSTReachabilityTests.swift
import XCTest
@testable import OST_Remote

final class OSTReachabilityTests: XCTestCase {
    func test_postsChangedNotificationWithNewState() {
        let r = OSTReachability.shared
        let exp = expectation(forNotification: OSTReachability.changedNotification, object: r, handler: nil)
        r._simulatePathChange(reachable: false)
        wait(for: [exp], timeout: 1)
        XCTAssertFalse(r.isReachable)
        r._simulatePathChange(reachable: true)
        XCTAssertTrue(r.isReachable)
    }
}
