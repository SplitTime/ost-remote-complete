import XCTest
@testable import OST_Remote

final class MenuRowTests: XCTestCase {
    func test_title_isSet() {
        let row = MenuRow(title: "Review / Sync")
        XCTAssertEqual(row.title, "Review / Sync")
    }

    func test_badge_hiddenWhenZero() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 0
        XCTAssertFalse(row.isShowingBadge)
    }

    func test_badge_shownWithCountWhenPositive() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 6
        XCTAssertTrue(row.isShowingBadge)
        XCTAssertEqual(row.badgeText, "6")
    }

    func test_badge_hidesAgainWhenClearedToZero() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 6
        row.badgeCount = 0
        XCTAssertFalse(row.isShowingBadge)
    }
}
