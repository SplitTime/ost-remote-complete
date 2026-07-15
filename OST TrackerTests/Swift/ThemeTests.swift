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

    func testWarningPaletteIsOrange() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        Palette.lightWarning.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)   // systemOrange ≈ (255,149,0)
        XCTAssertEqual(g, 149.0/255, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
    }

    func test_metrics_haveExpectedValues() {
        XCTAssertEqual(Theme.Metric.cornerRadius, 10)
        XCTAssertEqual(Theme.Metric.fieldHeight, 48)
        XCTAssertEqual(Theme.Metric.buttonHeight, 52)
        XCTAssertEqual(Theme.Metric.horizontalInset, 28)
    }
}
