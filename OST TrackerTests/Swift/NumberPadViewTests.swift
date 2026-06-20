import XCTest
@testable import OST_Remote

final class NumberPadViewTests: XCTestCase {

    func test_insertDigit_appendsToTextField() {
        let field = UITextField()
        let pad = NumberPadView()
        pad.attach(to: field)

        pad.insertDigit("2")
        pad.insertDigit("2")

        XCTAssertEqual(field.text, "22")
    }

    func test_deleteBackward_removesLastCharacter() {
        let field = UITextField()
        field.text = "123"
        let pad = NumberPadView()
        pad.attach(to: field)

        pad.deleteBackward()

        XCTAssertEqual(field.text, "12")
    }

    func test_deleteBackward_onEmptyField_isNoOp() {
        let field = UITextField()
        let pad = NumberPadView()
        pad.attach(to: field)

        pad.deleteBackward()

        XCTAssertEqual(field.text ?? "", "")
    }

    func test_insertDigit_withNoAttachedField_doesNotCrash() {
        let pad = NumberPadView()
        pad.insertDigit("5")
        // No attached field: nothing to assert beyond "did not crash".
    }
}
