import XCTest
@testable import OST_Remote

final class ReviewEntryCellTests: XCTestCase {

    private func display(name: String? = "Jane Doe", bib: String? = "142",
                         submitted: Bool = false, pacer: String? = "0", stopped: String? = "0") -> ReviewEntryDisplay {
        ReviewEntryDisplay(displayTime: "7:42:10", fullName: name, bibNumber: bib,
                           bitKey: "in", submitted: submitted, withPacer: pacer, stoppedHere: stopped)
    }

    func test_configure_setsText() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display())
        XCTAssertEqual(cell.timeText, "7:42:10")
        XCTAssertEqual(cell.nameText, "Jane Doe")
        XCTAssertEqual(cell.bibText, "#142")
        XCTAssertEqual(cell.inOutText, "In")
    }

    func test_configure_placeholderBib_blankLabel() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(bib: "-1"))
        XCTAssertEqual(cell.bibText, "")
    }

    func test_configure_appliesStyle() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        let d = display(name: "", submitted: false) // unsynced + missing
        cell.configure(with: d)
        XCTAssertEqual(cell.appliedStyle, ReviewEntryStyle(d))
        XCTAssertEqual(cell.appliedStyle?.nameRole, .destructive)
    }

    func test_configure_iconVisibility() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(pacer: "1", stopped: "0"))
        XCTAssertFalse(cell.isPacerHidden)
        XCTAssertTrue(cell.isStoppedHidden)
    }

    func test_configure_reusedCell_updatesStyle() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(name: "", submitted: false))   // unsynced + missing
        cell.configure(with: display(name: "Jane Doe", submitted: true)) // synced + found
        XCTAssertEqual(cell.appliedStyle?.nameRole, .normal)
        XCTAssertTrue(cell.appliedStyle?.isSynced ?? false)
    }

    func test_configure_synced_showsTintAndCheck() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(submitted: true))
        XCTAssertTrue(cell.isSyncedRow)
        XCTAssertFalse(cell.isCheckHidden, "a synced row shows the trailing green check")
    }

    func test_configure_unsynced_hidesTintAndCheck() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(submitted: false))
        XCTAssertFalse(cell.isSyncedRow)
        XCTAssertTrue(cell.isCheckHidden, "an unsynced row shows no check")
    }

    func test_configure_reusedCell_clearsSyncedState() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(submitted: true))   // synced
        cell.configure(with: display(submitted: false))  // reused as unsynced
        XCTAssertFalse(cell.isSyncedRow)
        XCTAssertTrue(cell.isCheckHidden)
    }

    func test_header_setsTitle() {
        let header = ReviewSectionHeaderView(reuseIdentifier: nil)
        header.configure(title: "Start Entries:")
        XCTAssertEqual(header.titleText, "Start Entries:")
    }
}
