import XCTest
@testable import OST_Remote

final class BottomSheetPickerTests: XCTestCase {
    func test_choose_firesCallbackWithOption() {
        var fired: String?
        let sheet = BottomSheetPicker(title: "Aid Station",
                                      options: ["Tony Grove", "Temple Fork"],
                                      selected: nil) { fired = $0 }
        sheet.loadViewIfNeeded()
        sheet.choose("Temple Fork")
        XCTAssertEqual(fired, "Temple Fork")
    }

    /// Regression: the option list lives in a UIScrollView. A scroll view has no
    /// intrinsic content size, so without an explicit height it collapses to 0
    /// inside the vertical content stack — the drawer would show only its title.
    /// After laying out with options, the scroll view must have a real height.
    func test_optionRows_layOutWithNonzeroHeight() {
        let sheet = BottomSheetPicker(title: "Aid Station",
                                      options: ["A", "B", "C"],
                                      selected: nil) { _ in }
        sheet.loadViewIfNeeded()
        sheet.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        sheet.view.layoutIfNeeded()

        let scroll = sheet.view.firstSubview(withIdentifier: "BottomSheetPicker.scroll")
        XCTAssertNotNil(scroll, "scroll view should exist and be findable")
        XCTAssertGreaterThan(scroll?.frame.height ?? 0, 0,
                             "scroll view must have nonzero height so option rows are visible")
    }
}

private extension UIView {
    func firstSubview(withIdentifier id: String) -> UIView? {
        if accessibilityIdentifier == id { return self }
        for sub in subviews {
            if let found = sub.firstSubview(withIdentifier: id) { return found }
        }
        return nil
    }
}
