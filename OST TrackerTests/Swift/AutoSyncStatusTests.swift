// OST TrackerTests/Swift/AutoSyncStatusTests.swift
import XCTest
@testable import OST_Remote

final class AutoSyncStatusTests: XCTestCase {
    func test_stripText_perState() {
        let d = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(AutoSyncStatus(state: .pending, pendingCount: 3, lastSyncDate: nil).stripText,
                       "Auto Sync · 3 to sync…")
        XCTAssertEqual(AutoSyncStatus(state: .syncing, pendingCount: 3, lastSyncDate: nil).stripText,
                       "Auto Sync · Syncing 3…")
        XCTAssertEqual(AutoSyncStatus(state: .failed, pendingCount: 2, lastSyncDate: nil).stripText,
                       "Sync failed · retrying soon · 2 pending")
        XCTAssertEqual(AutoSyncStatus(state: .offline, pendingCount: 1, lastSyncDate: nil).stripText,
                       "Offline · 1 waiting to sync")
        XCTAssertTrue(AutoSyncStatus(state: .synced, pendingCount: 0, lastSyncDate: d).stripText.hasPrefix("Auto Sync · All synced · "))
    }

    func test_isTappableForRetry_onlyFailedOrOffline() {
        XCTAssertTrue(AutoSyncStatus(state: .failed, pendingCount: 1, lastSyncDate: nil).isTappableForRetry)
        XCTAssertTrue(AutoSyncStatus(state: .offline, pendingCount: 1, lastSyncDate: nil).isTappableForRetry)
        XCTAssertFalse(AutoSyncStatus(state: .syncing, pendingCount: 1, lastSyncDate: nil).isTappableForRetry)
        XCTAssertFalse(AutoSyncStatus(state: .synced, pendingCount: 0, lastSyncDate: nil).isTappableForRetry)
    }
}
