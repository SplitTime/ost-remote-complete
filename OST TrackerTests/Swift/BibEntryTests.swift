import XCTest
@testable import OST_Remote

final class BibEntryTests: XCTestCase {

    func test_isRecordable_isFalse_forNil() {
        XCTAssertFalse(BibEntry.isRecordable(nil))
    }

    func test_isRecordable_isFalse_forEmptyString() {
        XCTAssertFalse(BibEntry.isRecordable(""))
    }

    func test_isRecordable_isTrue_forNonEmptyBib() {
        XCTAssertTrue(BibEntry.isRecordable("42"))
    }

    // MARK: - entryButtonLayout permutations

    private func entry(_ kind: String, _ label: String) -> [String: Any] {
        ["subSplitKind": kind, "label": label]
    }

    func test_entryButtonLayout_singleIn_hidesRight() {
        let layout = entryButtonLayout(for: [entry("in", "In")])
        XCTAssertEqual(layout, EntryButtonLayout(leftTitle: "In", rightHidden: true, leftBitKey: "in"))
    }

    func test_entryButtonLayout_singleOut_hidesLeft() {
        let layout = entryButtonLayout(for: [entry("out", "Out")])
        XCTAssertEqual(layout, EntryButtonLayout(rightTitle: "Out", leftHidden: true, rightBitKey: "out"))
    }

    func test_entryButtonLayout_inAndOut() {
        let layout = entryButtonLayout(for: [entry("in", "In"), entry("out", "Out")])
        XCTAssertEqual(layout, EntryButtonLayout(leftTitle: "In", rightTitle: "Out",
                                                 leftBitKey: "in", rightBitKey: "out"))
    }

    func test_entryButtonLayout_twoIn() {
        let layout = entryButtonLayout(for: [entry("in", "In A"), entry("in", "In B")])
        XCTAssertEqual(layout, EntryButtonLayout(leftTitle: "In A", rightTitle: "In B",
                                                 leftBitKey: "in", rightBitKey: "in"))
    }

    func test_entryButtonLayout_twoOut() {
        let layout = entryButtonLayout(for: [entry("out", "Out A"), entry("out", "Out B")])
        XCTAssertEqual(layout, EntryButtonLayout(leftTitle: "Out A", rightTitle: "Out B",
                                                 leftBitKey: "out", rightBitKey: "out"))
    }

    func test_entryButtonLayout_degenerate_bothVisibleNoKeys() {
        XCTAssertEqual(entryButtonLayout(for: []), EntryButtonLayout())
    }
}
