import XCTest
@testable import OST_Remote

private final class BreadcrumbActionSpy: NSObject {
    @objc func onLiveEntry() {}
}

final class PrimaryButtonTests: XCTestCase {
    func test_setsTitleAndCornerRadius() {
        let b = PrimaryButton(title: "Log In")
        XCTAssertEqual(b.title(for: .normal), "Log In")
        XCTAssertEqual(b.layer.cornerRadius, Theme.Metric.cornerRadius)
    }

    func test_heightConstraintMatchesMetric() {
        let b = PrimaryButton(title: "Go")
        let h = b.constraints.first { $0.firstAttribute == .height }
        XCTAssertEqual(h?.constant, Theme.Metric.buttonHeight)
    }

    func test_breadcrumb_titleIsLiveEntryWithChevron() {
        let button = UIButton(type: .system)
        button.configureAsBreadcrumb(target: BreadcrumbActionSpy(), action: #selector(BreadcrumbActionSpy.onLiveEntry))
        XCTAssertEqual(button.title(for: .normal), "\u{2039} Live Entry")
    }

    func test_breadcrumb_hasBackAccessibilityLabel() {
        let button = UIButton(type: .system)
        button.configureAsBreadcrumb(target: BreadcrumbActionSpy(), action: #selector(BreadcrumbActionSpy.onLiveEntry))
        XCTAssertEqual(button.accessibilityLabel, "Back to Live Entry")
    }

    func test_breadcrumb_wiresTargetAction() {
        let spy = BreadcrumbActionSpy()
        let button = UIButton(type: .system)
        button.configureAsBreadcrumb(target: spy, action: #selector(BreadcrumbActionSpy.onLiveEntry))
        let actions = button.actions(forTarget: spy, forControlEvent: .touchUpInside) ?? []
        XCTAssertTrue(actions.contains("onLiveEntry"))
    }
}
