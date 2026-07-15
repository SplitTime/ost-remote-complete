import XCTest
@testable import OST_Remote

/// Proves the XCTest harness runs and `@testable import` of the app module works
/// after the TEST_HOST repair. Replaced/expanded by real foundation tests.
final class HarnessSmokeTests: XCTestCase {
    func test_swiftModuleIsTestable() {
        XCTAssertEqual(SwiftSmoke.ping(), "swift-ok")
    }
}
