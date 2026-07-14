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

    // The pad assigns `.text` directly, which does not fire `.editingChanged`.
    // Hosts (e.g. the edit-entry screen's found/not-found label) rely on
    // `onChange` to refresh after each tap.
    func test_insertDigit_firesOnChange() {
        let field = UITextField()
        let pad = NumberPadView()
        pad.attach(to: field)
        var calls = 0
        pad.onChange = { calls += 1 }

        pad.insertDigit("4")

        XCTAssertEqual(calls, 1)
    }

    func test_deleteBackward_firesOnChange() {
        let field = UITextField()
        field.text = "12"
        let pad = NumberPadView()
        pad.attach(to: field)
        var calls = 0
        pad.onChange = { calls += 1 }

        pad.deleteBackward()

        XCTAssertEqual(calls, 1)
    }

    func test_deleteBackward_onEmptyField_doesNotFireOnChange() {
        let field = UITextField()
        let pad = NumberPadView()
        pad.attach(to: field)
        var calls = 0
        pad.onChange = { calls += 1 }

        pad.deleteBackward()

        XCTAssertEqual(calls, 0, "no edit happened, so no change should be reported")
    }

    func test_insertDigit_withNoAttachedField_doesNotCrash() {
        let pad = NumberPadView()
        pad.insertDigit("5")
        // No attached field: nothing to assert beyond "did not crash".
    }

    // A custom view used as a UITextField.inputView is invisible without a
    // non-zero height. The pad must size itself by default so it renders when
    // assigned as an inputView (the edit-entry screen does exactly that).
    func test_hasNonZeroDefaultHeight_soItRendersAsInputView() {
        let pad = NumberPadView()
        XCTAssertGreaterThan(pad.frame.height, 0)
        XCTAssertGreaterThan(pad.frame.width, 0)
    }
}
