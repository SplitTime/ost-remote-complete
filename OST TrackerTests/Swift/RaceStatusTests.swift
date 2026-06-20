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

extension RaceStatusTests {
    private func mtZone() -> TimeZone { TimeZone(secondsFromGMT: -6 * 3600)! }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tz: TimeZone) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.date(from: c)!
    }

    func test_elapsedFormatsHoursAndMinutes() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 6, 0, tz: tz)
        let t = date(2022, 7, 22, 9, 13, tz: tz)
        XCTAssertEqual(RaceStatusFormat.elapsed(from: start, to: t), "3:13")
    }

    func test_elapsedExceeds24Hours() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 6, 0, tz: tz)
        let t = date(2022, 7, 23, 6, 20, tz: tz)
        XCTAssertEqual(RaceStatusFormat.elapsed(from: start, to: t), "24:20")
    }

    func test_timeOfDayInEventZone() {
        let tz = mtZone()
        let t = date(2022, 7, 22, 9, 13, tz: tz)
        XCTAssertEqual(RaceStatusFormat.timeOfDay(t, in: tz), "09:13")
    }

    func test_dayOffsetCrossesMidnight() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 6, 0, tz: tz)
        let sameDay = date(2022, 7, 22, 23, 0, tz: tz)
        let nextDay = date(2022, 7, 23, 2, 0, tz: tz)
        XCTAssertEqual(RaceStatusFormat.dayOffset(from: start, to: sameDay, in: tz), 0)
        XCTAssertEqual(RaceStatusFormat.dayOffset(from: start, to: nextDay, in: tz), 1)
    }
}
