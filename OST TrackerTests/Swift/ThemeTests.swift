import XCTest
@testable import OST_Remote

final class ThemeTests: XCTestCase {
    func test_dynamic_resolvesByTrait_oniOS13() {
        guard #available(iOS 13.0, *) else { return }
        let c = Theme.dynamic(light: .red, dark: .blue)
        XCTAssertEqual(c.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)), .red)
        XCTAssertEqual(c.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)), .blue)
    }

    func test_roles_lightAndDarkDiffer_oniOS13() {
        guard #available(iOS 13.0, *) else { return }
        let light = Theme.background.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = Theme.background.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertNotEqual(light, dark, "background must differ between light and dark")
    }

    func test_metrics_haveExpectedValues() {
        XCTAssertEqual(Theme.Metric.cornerRadius, 10)
        XCTAssertEqual(Theme.Metric.fieldHeight, 48)
        XCTAssertEqual(Theme.Metric.buttonHeight, 52)
    }
}
