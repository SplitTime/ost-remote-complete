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

    func test_detailText_setsLabelAndShows() {
        let row = MenuRow(title: "Appearance")
        row.detailText = "System"
        XCTAssertEqual(row.detailLabelText, "System")
        XCTAssertTrue(row.isShowingDetail)
    }

    func test_detailText_hiddenWhenNil() {
        let row = MenuRow(title: "Appearance")
        XCTAssertFalse(row.isShowingDetail)
    }

    func test_detailText_hiddenWhenClearedToNil() {
        let row = MenuRow(title: "Appearance")
        row.detailText = "Dark"
        row.detailText = nil
        XCTAssertFalse(row.isShowingDetail)
    }

    func test_chevron_shownByDefault() {
        let row = MenuRow(title: "About")
        XCTAssertTrue(row.isShowingChevron)
    }

    func test_chevron_hiddenWhenShowsChevronFalse() {
        let row = MenuRow(title: "Refresh Roster")
        row.showsChevron = false
        XCTAssertFalse(row.isShowingChevron)
    }
}
