import XCTest
@testable import OST_Remote

private final class HeaderActionSpy: NSObject {
    @objc func onLiveEntry() {}
    @objc func onMenu() {}
}

final class ScreenHeaderTests: XCTestCase {

    private func make(trailing: [UIView] = []) -> (header: UIStackView, menuButton: UIButton, title: UILabel, spy: HeaderActionSpy) {
        let title = UILabel()
        title.text = "Cross Check"
        let spy = HeaderActionSpy()
        let result = ScreenHeader.make(titleLabel: title,
                                       trailingActions: trailing,
                                       target: spy,
                                       onLiveEntry: #selector(HeaderActionSpy.onLiveEntry),
                                       onMenu: #selector(HeaderActionSpy.onMenu))
        return (result.header, result.menuButton, title, spy)
    }

    func test_header_isVerticalUtilityRowOverTitle() {
        let (header, _, title, _) = make()
        XCTAssertEqual(header.axis, .vertical)
        XCTAssertEqual(header.arrangedSubviews.count, 2)
        XCTAssertTrue(header.arrangedSubviews[0] is UIStackView)   // utility row
        XCTAssertTrue(header.arrangedSubviews[1] === title)        // title on its own line
    }

    func test_title_usesStandardTitleFont() {
        let (_, _, title, _) = make()
        XCTAssertEqual(title.font, Theme.Font.title)
    }

    func test_utilityRow_startsWithBreadcrumb_endsWithMenu() {
        let (header, menu, _, _) = make()
        let row = header.arrangedSubviews[0] as! UIStackView
        let first = row.arrangedSubviews.first as? UIButton
        XCTAssertEqual(first?.title(for: .normal), "\u{2039} Live Entry")
        XCTAssertTrue(row.arrangedSubviews.last === menu)
        XCTAssertEqual(menu.accessibilityLabel, "Menu")
    }

    func test_trailingActions_appearBeforeMenu() {
        let action = UIButton(type: .system)
        let (header, menu, _, _) = make(trailing: [action])
        let row = header.arrangedSubviews[0] as! UIStackView
        let menuIndex = row.arrangedSubviews.firstIndex(where: { $0 === menu })!
        let actionIndex = row.arrangedSubviews.firstIndex(where: { $0 === action })!
        XCTAssertLessThan(actionIndex, menuIndex)
        XCTAssertGreaterThan(actionIndex, 0) // after the breadcrumb/spacer, not first
    }

    func test_breadcrumb_wiredToTarget() {
        let (header, _, _, spy) = make()
        let row = header.arrangedSubviews[0] as! UIStackView
        let crumb = row.arrangedSubviews.first as! UIButton
        let actions = crumb.actions(forTarget: spy, forControlEvent: .touchUpInside) ?? []
        XCTAssertTrue(actions.contains("onLiveEntry"))
    }
}
