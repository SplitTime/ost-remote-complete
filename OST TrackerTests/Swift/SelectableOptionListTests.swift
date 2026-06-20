import XCTest
@testable import OST_Remote

final class SelectableOptionListTests: XCTestCase {
    func test_select_setsSelection_andFiresCallback() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["Bear 100 — 2026", "Wasatch 100"]
        var fired: String?
        list.onSelect = { fired = $0 }
        list.select("Wasatch 100")
        XCTAssertEqual(list.selectedOption, "Wasatch 100")
        XCTAssertEqual(fired, "Wasatch 100")
    }

    func test_select_ignoresUnknownOption() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("Nope")
        XCTAssertNil(list.selectedOption)
    }

    func test_reset_clearsSelection() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("A")
        list.reset()
        XCTAssertNil(list.selectedOption)
    }
}
