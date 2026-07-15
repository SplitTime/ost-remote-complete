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

    /// Hosts a row at a fixed width in a container and returns the container so the
    /// caller can mutate the row and re-run layout.
    private func hosted(_ row: MenuRow, width: CGFloat = 270) -> UIView {
        row.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 52))
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor),
        ])
        container.layoutIfNeeded()
        return container
    }

    // The chevron is anchored to the trailing edge (16pt inset) regardless of
    // title length — short titles must not pull it inward.
    func test_chevron_isFlushRight_forShortTitle() {
        let row = MenuRow(title: "About")
        _ = hosted(row)
        XCTAssertEqual(row.chevronMaxXInRow, 270 - 16, accuracy: 1.0)
    }

    // Regression (iOS 26): showing then hiding the badge used to let the row stack
    // redistribute slack and strand the chevron mid-row. It must stay flush-right.
    func test_chevron_staysFlushRight_afterBadgeToggles() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 6
        let container = hosted(row)
        row.badgeCount = 0
        container.layoutIfNeeded()
        XCTAssertEqual(row.chevronMaxXInRow, 270 - 16, accuracy: 1.0)
    }
}
