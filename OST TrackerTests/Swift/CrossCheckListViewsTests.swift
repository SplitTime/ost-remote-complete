import XCTest
@testable import OST_Remote

final class CrossCheckListViewsTests: XCTestCase {
    func testExpectedCellShowsBibAndName() {
        let cell = CrossCheckExpectedCell(style: .default, reuseIdentifier: CrossCheckExpectedCell.reuseID)
        cell.configure(with: CrossCheckRow(bib: "214", name: "Dean Karnazes", status: .expected, time: nil))
        XCTAssertEqual(cell.bibText, "214")
        XCTAssertEqual(cell.nameText, "Dean Karnazes")
    }

    func testSummaryCellShowsTitleAndCount() {
        let cell = CrossCheckSummaryCell(style: .default, reuseIdentifier: CrossCheckSummaryCell.reuseID)
        cell.configure(status: .recorded, title: "Recorded", count: 61)
        XCTAssertEqual(cell.titleText, "Recorded")
        XCTAssertEqual(cell.countText, "61")
        XCTAssertEqual(cell.dotColor, CrossCheckStatus.recorded.dotColor)
    }
}
