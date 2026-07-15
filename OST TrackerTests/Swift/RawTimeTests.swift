import XCTest
@testable import OST_Remote

final class RawTimeTests: XCTestCase {

    private func loadFixture() -> [String: Any] {
        let data = Fixture.data("raw_times_437")
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    func test_parse_returnsAllRows() {
        let rows = RawTime.parse(loadFixture())
        XCTAssertEqual(rows.count, 2)
    }

    func test_parse_mapsCoreFields() {
        let rows = RawTime.parse(loadFixture())
        let first = rows[0]
        XCTAssertEqual(first.id, 1001)
        XCTAssertEqual(first.bib, "57")
        XCTAssertEqual(first.enteredTime, "10:42:03")
        XCTAssertEqual(first.subSplitKind, "in")
        XCTAssertEqual(first.source, "ost-timing-system")
        XCTAssertEqual(first.lap, 1)
        XCTAssertFalse(first.withPacer)
        XCTAssertFalse(first.stoppedHere)
    }

    func test_parse_handlesNullsAndFlags() {
        let rows = RawTime.parse(loadFixture())
        let second = rows[1]
        XCTAssertNil(second.enteredTime)
        XCTAssertEqual(second.absoluteTime, "2026-06-20T15:43:10.000Z")
        XCTAssertTrue(second.withPacer)
        XCTAssertTrue(second.stoppedHere)
    }

    func test_parse_skipsRowsMissingId() {
        let json: [String: Any] = ["data": [["type": "raw_times", "attributes": ["bibNumber": "99"]]]]
        XCTAssertTrue(RawTime.parse(json).isEmpty)
    }

    func test_parse_emptyDataReturnsEmpty() {
        XCTAssertTrue(RawTime.parse(["data": []]).isEmpty)
        XCTAssertTrue(RawTime.parse([:]).isEmpty)
    }
}
