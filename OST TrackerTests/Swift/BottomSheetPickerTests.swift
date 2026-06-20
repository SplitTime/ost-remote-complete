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
}
