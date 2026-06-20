import XCTest
@testable import OST_Remote

final class StyledTextFieldTests: XCTestCase {
    func test_secureField_isSecureAndPasswordContentType() {
        let tf = StyledTextField(placeholder: "Password", secure: true)
        XCTAssertTrue(tf.isSecureTextEntry)
        XCTAssertEqual(tf.textContentType, .password)
        XCTAssertEqual(tf.placeholder, "Password")
    }

    func test_plainField_isNotSecure_usernameContentType() {
        let tf = StyledTextField(placeholder: "Username", secure: false)
        XCTAssertFalse(tf.isSecureTextEntry)
        XCTAssertEqual(tf.textContentType, .username)
    }
}
