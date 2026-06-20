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

    func test_startsExpanded() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        XCTAssertTrue(list.isExpanded)
    }

    func test_select_collapsesWhenMultipleOptions() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("A")
        XCTAssertFalse(list.isExpanded, "selecting one of several options collapses the list")
    }

    func test_select_staysExpandedWhenSingleOption() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["Only"]
        list.select("Only")
        XCTAssertTrue(list.isExpanded, "a single-option list has nothing to collapse")
    }

    func test_expand_reExpandsAfterSelection() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("A")
        list.expand()
        XCTAssertTrue(list.isExpanded)
        XCTAssertEqual(list.selectedOption, "A", "re-expanding keeps the current selection")
    }

    func test_reset_expands() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("A")
        list.reset()
        XCTAssertTrue(list.isExpanded)
    }
}
