import XCTest
@testable import OST_Remote

final class AppearanceModeTests: XCTestCase {
    func test_displayName_forEachMode() {
        XCTAssertEqual(AppearanceMode.system.displayName, "System")
        XCTAssertEqual(AppearanceMode.light.displayName, "Light")
        XCTAssertEqual(AppearanceMode.dark.displayName, "Dark")
    }
}
