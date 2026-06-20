import XCTest
@testable import OST_Remote

final class RaceStatusTests: XCTestCase {

    private func loadSpread() throws -> EventSpread {
        try EventSpread.decode(from: Fixture.data("spread-test-lonesome-100"))
    }

    // MARK: - Parsing

    func test_parsesSpreadEnvelope() throws {
        let spread = try loadSpread()
        XCTAssertEqual(spread.name, "Test Lonesome 100")
        XCTAssertEqual(spread.splitHeaders.count, 18)
        XCTAssertEqual(spread.efforts.count, 151)
    }

    func test_splitHeaderExtensions() throws {
        let spread = try loadSpread()
        XCTAssertEqual(spread.splitHeaders[0].title, "Start")
        XCTAssertFalse(spread.splitHeaders[0].hasInOut)
        XCTAssertEqual(spread.splitHeaders[1].title, "Raspberry 1")
        XCTAssertEqual(spread.splitHeaders[1].extensions, ["In", "Out"])
        XCTAssertTrue(spread.splitHeaders[1].hasInOut)
    }

    func test_eventTimeZoneFromOffset() throws {
        let spread = try loadSpread()
        XCTAssertEqual(spread.eventTimeZone.secondsFromGMT(), -6 * 3600)
    }

    func test_effortRowParsesTimesAlignedToHeaders() throws {
        let spread = try loadSpread()
        let beer = try XCTUnwrap(spread.efforts.first { $0.bibNumber == 28 })
        XCTAssertEqual(beer.fullName, "Raul Beer")
        XCTAssertEqual(beer.overallRank, 1)
        XCTAssertTrue(beer.finished)
        // absoluteTimes aligned to the 18 headers; Raspberry 1 (idx 1) is In/Out.
        XCTAssertEqual(beer.absoluteTimes.count, 18)
        XCTAssertEqual(beer.absoluteTimes[1].count, 2)
        XCTAssertNotNil(beer.absoluteTimes[1][0]) // In time present
    }
}
