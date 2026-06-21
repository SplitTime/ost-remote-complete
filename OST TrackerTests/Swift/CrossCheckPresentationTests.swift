import XCTest
@testable import OST_Remote

final class CrossCheckPresentationTests: XCTestCase {

    private func facts(bib: String, name: String = "Runner",
                       hasEntries: Bool = false, isStopped: Bool = false,
                       isExpected: Bool = true, time: String? = nil) -> EffortFacts {
        EffortFacts(bib: bib, name: name, hasEntries: hasEntries,
                    isStopped: isStopped, isExpected: isExpected, time: time)
    }

    func testStatusDerivation() {
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "1", hasEntries: true, isStopped: false)), .recorded)
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "2", hasEntries: true, isStopped: true)), .droppedHere)
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "3", hasEntries: false, isExpected: true)), .expected)
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "4", hasEntries: false, isExpected: false)), .notExpected)
    }

    func testBuildBucketsAndCounts() {
        let board = CrossCheckPresentation.build(from: [
            facts(bib: "1", hasEntries: true),
            facts(bib: "2", hasEntries: true, isStopped: true),
            facts(bib: "3", isExpected: true),
            facts(bib: "4", isExpected: true),
            facts(bib: "5", isExpected: false),
        ])
        XCTAssertEqual(board.expectedCount, 2)
        XCTAssertEqual(board.recordedCount, 1)
        XCTAssertEqual(board.droppedHereCount, 1)
        XCTAssertEqual(board.notExpectedCount, 1)
        XCTAssertEqual(board.expected.map { $0.bib }, ["3", "4"])
    }

    func testBuildExcludesEmptyBib() {
        let board = CrossCheckPresentation.build(from: [
            facts(bib: "", isExpected: true),
            facts(bib: "7", isExpected: true),
        ])
        XCTAssertEqual(board.expected.map { $0.bib }, ["7"])
    }

    func testSheetConfigShowsToggleOnlyWhenNotRecorded() {
        let expectedRow = CrossCheckRow(bib: "3", name: "A", status: .expected, time: nil)
        let recordedRow = CrossCheckRow(bib: "1", name: "B", status: .recorded, time: "10:42")
        XCTAssertEqual(CrossCheckPresentation.sheetConfig(for: expectedRow),
                       CrossCheckSheetConfig(bib: "3", name: "A", showsExpectedToggle: true, isExpected: true))
        XCTAssertEqual(CrossCheckPresentation.sheetConfig(for: recordedRow),
                       CrossCheckSheetConfig(bib: "1", name: "B", showsExpectedToggle: false, isExpected: false))
    }
}
