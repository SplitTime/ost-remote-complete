import XCTest
@testable import OST_Remote

final class LiveReadsMergeTests: XCTestCase {

    private func read(_ id: Int) -> RawTime {
        RawTime(id: id, bib: "\(id)", enteredTime: nil, absoluteTime: nil,
                subSplitKind: "in", source: "t", lap: 1, withPacer: false, stoppedHere: false)
    }

    func test_firstLoad_fromZeroHwm_noNewHighlights() {
        let result = LiveReadsMerge.merge(existing: [], incoming: [read(3), read(2), read(1)], highWaterMark: 0)
        XCTAssertEqual(result.rows.map { $0.id }, [3, 2, 1])
        XCTAssertEqual(result.newIds, [3, 2, 1])   // all above hwm 0
        XCTAssertEqual(result.highWaterMark, 3)
    }

    func test_subsequentPoll_detectsOnlyNewIds() {
        let existing = [read(3), read(2), read(1)]
        let incoming = [read(5), read(4), read(3)]   // 3 overlaps, 4 & 5 new
        let result = LiveReadsMerge.merge(existing: existing, incoming: incoming, highWaterMark: 3)
        XCTAssertEqual(result.rows.map { $0.id }, [5, 4, 3, 2, 1])
        XCTAssertEqual(result.newIds.sorted(), [4, 5])
        XCTAssertEqual(result.highWaterMark, 5)
    }

    func test_noNewRows_isStable() {
        let existing = [read(2), read(1)]
        let result = LiveReadsMerge.merge(existing: existing, incoming: [read(2), read(1)], highWaterMark: 2)
        XCTAssertEqual(result.rows.map { $0.id }, [2, 1])
        XCTAssertTrue(result.newIds.isEmpty)
        XCTAssertEqual(result.highWaterMark, 2)
    }

    func test_emptyIncoming_keepsExisting() {
        let existing = [read(2), read(1)]
        let result = LiveReadsMerge.merge(existing: existing, incoming: [], highWaterMark: 2)
        XCTAssertEqual(result.rows.map { $0.id }, [2, 1])
        XCTAssertTrue(result.newIds.isEmpty)
        XCTAssertEqual(result.highWaterMark, 2)
    }
}
