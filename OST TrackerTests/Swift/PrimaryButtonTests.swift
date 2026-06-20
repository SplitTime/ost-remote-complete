import XCTest
@testable import OST_Remote

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
}
