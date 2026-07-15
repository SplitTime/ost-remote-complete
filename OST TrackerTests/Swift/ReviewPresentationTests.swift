import XCTest
@testable import OST_Remote

final class ReviewPresentationTests: XCTestCase {

    private func display(name: String? = "Jane Doe", bib: String? = "142",
                         bitKey: String? = "in", submitted: Bool = false,
                         pacer: String? = "0", stopped: String? = "0") -> ReviewEntryDisplay {
        ReviewEntryDisplay(displayTime: "7:42:10", fullName: name, bibNumber: bib,
                           bitKey: bitKey, submitted: submitted, withPacer: pacer, stoppedHere: stopped)
    }

    // Display mapping
    func test_display_resolvesName() {
        XCTAssertEqual(display(name: "Jane Doe").name, "Jane Doe")
        XCTAssertFalse(display(name: "Jane Doe").isBibMissing)
    }

    func test_display_emptyName_becomesBibNotFound() {
        let d = display(name: "")
        XCTAssertEqual(d.name, "Bib not found")
        XCTAssertTrue(d.isBibMissing)
    }

    func test_display_nilName_becomesBibNotFound() {
        XCTAssertTrue(display(name: nil).isBibMissing)
    }

    func test_display_bibFormatting() {
        XCTAssertEqual(display(bib: "142").bib, "#142")
    }

    func test_display_placeholderBib_isNil() {
        XCTAssertNil(display(bib: "-1").bib)
        XCTAssertNil(display(bib: nil).bib)
    }

    func test_display_emptyBib_isNil_notLoneHash() {
        XCTAssertNil(display(bib: "").bib, "an empty bib must render no chip, not a lone \"#\"")
    }

    func test_display_inOutCapitalized() {
        XCTAssertEqual(display(bitKey: "in").inOut, "In")
        XCTAssertEqual(display(bitKey: "out").inOut, "Out")
    }

    func test_display_pacerAndStoppedTruthiness() {
        XCTAssertTrue(display(pacer: "1").showsPacer)
        XCTAssertFalse(display(pacer: "0").showsPacer)
        XCTAssertTrue(display(stopped: "true").showsStopped)
        XCTAssertFalse(display(stopped: nil).showsStopped)
    }

    // Style roles — synced-ness no longer recolors the text; it drives the cell's
    // green tint + trailing check (style.isSynced). Text keeps the same readable
    // hierarchy as unsynced rows so a synced row stays legible.
    func test_style_syncedFound_readableRoles_marksSynced() {
        let s = ReviewEntryStyle(display(submitted: true))
        XCTAssertEqual(s.timeRole, .normal)
        XCTAssertEqual(s.nameRole, .normal)
        XCTAssertEqual(s.bibRole, .secondary)
        XCTAssertEqual(s.inOutRole, .secondary)
        XCTAssertFalse(s.nameBold)
        XCTAssertTrue(s.isSynced)
    }

    func test_style_syncedMissing_keepsMissingWarning() {
        let s = ReviewEntryStyle(display(name: "", submitted: true))
        XCTAssertEqual(s.nameRole, .destructive, "a missing bib stays flagged even once synced")
        XCTAssertTrue(s.nameBold)
        XCTAssertTrue(s.isSynced)
    }

    func test_style_unsyncedFound_normal_notBold_notSynced() {
        let s = ReviewEntryStyle(display())
        XCTAssertEqual(s.timeRole, .normal)
        XCTAssertEqual(s.nameRole, .normal)
        XCTAssertEqual(s.bibRole, .secondary)
        XCTAssertEqual(s.inOutRole, .secondary)
        XCTAssertFalse(s.nameBold)
        XCTAssertFalse(s.isSynced)
    }

    func test_style_unsyncedMissing_destructiveBold() {
        let s = ReviewEntryStyle(display(name: ""))
        XCTAssertEqual(s.nameRole, .destructive)
        XCTAssertTrue(s.nameBold)
        XCTAssertFalse(s.isSynced)
    }

    // Sync button
    func test_syncTitle_zero_allSynced() {
        XCTAssertEqual(ReviewSyncButton.title(unsyncedCount: 0), "All Synced")
    }

    func test_syncTitle_one_singular() {
        XCTAssertEqual(ReviewSyncButton.title(unsyncedCount: 1), "Sync 1 Time")
    }

    func test_syncTitle_many_plural() {
        XCTAssertEqual(ReviewSyncButton.title(unsyncedCount: 12), "Sync 12 Times")
    }

    func test_syncEnabled_rules() {
        XCTAssertTrue(ReviewSyncButton.isEnabled(unsyncedCount: 3, isSyncing: false))
        XCTAssertFalse(ReviewSyncButton.isEnabled(unsyncedCount: 0, isSyncing: false))
        XCTAssertFalse(ReviewSyncButton.isEnabled(unsyncedCount: 3, isSyncing: true))
    }
}
