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

extension RaceStatusTests {
    private func headers(_ n: Int) -> [SplitHeader] {
        (0..<n).map { SplitHeader(title: "S\($0)", splitName: "S\($0)",
                                  distanceMeters: Double($0) * 1000, extensions: ["In", "Out"], lap: 1) }
    }
    private func effort(bib: Int, times: [[Date?]], dropped: Bool = false, finished: Bool = false) -> EffortRow {
        EffortRow(overallRank: bib, genderRank: bib, bibNumber: bib, firstName: "F\(bib)",
                  lastName: "L\(bib)", dropped: dropped, finished: finished, absoluteTimes: times)
    }

    func test_furthestSplitIndex() {
        let t = Date()
        let e = effort(bib: 1, times: [[t, t], [t, nil], [nil, nil]])
        XCTAssertEqual(furthestSplitIndex(e), 1)
        let none = effort(bib: 2, times: [[nil, nil], [nil, nil]])
        XCTAssertEqual(furthestSplitIndex(none), -1)
    }

    func test_status_through_expected_dropped_notStarted() {
        let h = headers(4)
        let t = Date()
        // Through idx 2 (has an In time there)
        let through = effort(bib: 1, times: [[t, t], [t, t], [t, nil], [nil, nil]])
        XCTAssertEqual(effortStatus(through, atSplit: 2, headers: h), .through(arrival: t))
        // Expected at idx 2: cleared idx 1, no time at idx 2, not dropped
        let expected = effort(bib: 2, times: [[t, t], [t, t], [nil, nil], [nil, nil]])
        XCTAssertEqual(effortStatus(expected, atSplit: 2, headers: h), .expected)
        // Dropped before idx 2: furthest reached is idx 1 ("S1")
        let dropped = effort(bib: 3, times: [[t, t], [t, nil], [nil, nil], [nil, nil]], dropped: true)
        XCTAssertEqual(effortStatus(dropped, atSplit: 2, headers: h), .dropped(atStation: "S1"))
        // Not started: no times at all
        let none = effort(bib: 4, times: [[nil, nil], [nil, nil], [nil, nil], [nil, nil]])
        XCTAssertEqual(effortStatus(none, atSplit: 2, headers: h), .notStarted)
    }
}
