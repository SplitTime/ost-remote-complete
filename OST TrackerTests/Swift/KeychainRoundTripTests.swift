import XCTest
@testable import OST_Remote

/// Diagnoses whether OSTSessionManager (A0SimpleKeychain) actually persists
/// credentials in this build/sim environment. If this fails, autoLogin reads nil
/// creds and the legacy login crashes building a dict with a nil value.
final class KeychainRoundTripTests: XCTestCase {
    func test_sessionManagerPersistsCredentials() {
        OSTSessionManager.setUserName("round-trip@example.com", andPassword: "pw-123")
        XCTAssertEqual(OSTSessionManager.getStoredUserName(), "round-trip@example.com")
        XCTAssertEqual(OSTSessionManager.getStoredPassword(), "pw-123")
    }
}
