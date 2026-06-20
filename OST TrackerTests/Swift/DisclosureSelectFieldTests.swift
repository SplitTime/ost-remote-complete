import XCTest
@testable import OST_Remote

final class DisclosureSelectFieldTests: XCTestCase {
    func test_select_setsSelection_collapses_andFiresCallback() {
        let field = DisclosureSelectField(label: "Event", placeholder: "Choose an event")
        field.options = ["Bear 100 — 2026", "Wasatch 100"]
        var fired: String?
        field.onSelect = { fired = $0 }

        field.toggleExpanded()
        XCTAssertTrue(field.isExpanded)

        field.select("Wasatch 100")
        XCTAssertEqual(field.selectedOption, "Wasatch 100")
        XCTAssertFalse(field.isExpanded, "selecting collapses the list")
        XCTAssertEqual(fired, "Wasatch 100")
    }

    func test_toggleExpanded_flipsState() {
        let field = DisclosureSelectField(label: "Aid Station", placeholder: "Select…")
        XCTAssertFalse(field.isExpanded)
        field.toggleExpanded(); XCTAssertTrue(field.isExpanded)
        field.toggleExpanded(); XCTAssertFalse(field.isExpanded)
    }

    func test_reset_clearsSelectionAndCollapses() {
        let field = DisclosureSelectField(label: "Aid Station", placeholder: "Select…")
        field.options = ["A", "B"]
        field.select("A")
        field.reset()
        XCTAssertNil(field.selectedOption)
        XCTAssertFalse(field.isExpanded)
    }
}
