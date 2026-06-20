import XCTest
@testable import OST_Remote

final class AppearanceControllerTests: XCTestCase {
    private func freshDefaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func test_defaultMode_isSystem() {
        let sut = AppearanceController(defaults: freshDefaults("ap.default"))
        XCTAssertEqual(sut.mode, .system)
    }

    func test_modePersistsAcrossInstances() {
        let d = freshDefaults("ap.persist")
        AppearanceController(defaults: d).mode = .dark
        XCTAssertEqual(AppearanceController(defaults: d).mode, .dark)
    }

    func test_interfaceStyleMapping_oniOS13() {
        guard #available(iOS 13.0, *) else { return }
        let sut = AppearanceController(defaults: freshDefaults("ap.style"))
        sut.mode = .light;  XCTAssertEqual(sut.interfaceStyle, .light)
        sut.mode = .dark;   XCTAssertEqual(sut.interfaceStyle, .dark)
        sut.mode = .system; XCTAssertEqual(sut.interfaceStyle, .unspecified)
    }
}
