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

    func test_elapsedNegativeIntervalReturnsDash() {
        let tz = mtZone()
        let start = date(2022, 7, 22, 9, 0, tz: tz)
        let earlier = date(2022, 7, 22, 6, 0, tz: tz)
        XCTAssertEqual(RaceStatusFormat.elapsed(from: start, to: earlier), "—")
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

extension RaceStatusTests {
    func test_sortedField_groupsAndOrders() {
        let h = headers(4)
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)
        let throughLate  = effort(bib: 10, times: [[late, late], [late, late], [late, nil], [nil, nil]])
        let throughEarly = effort(bib: 11, times: [[early, early], [early, early], [early, nil], [nil, nil]])
        let expected     = effort(bib: 12, times: [[early, early], [early, early], [nil, nil], [nil, nil]])
        let dropped      = effort(bib: 13, times: [[early, nil], [nil, nil], [nil, nil], [nil, nil]], dropped: true)
        let notStarted   = effort(bib: 14, times: [[nil, nil], [nil, nil], [nil, nil], [nil, nil]])

        let ordered = sortedField([dropped, expected, throughLate, notStarted, throughEarly],
                                  atSplit: 2, headers: h)
        XCTAssertEqual(ordered.map { $0.bibNumber }, [11, 10, 12, 13, 14])
    }

    func test_matchEfforts_bibAndName() {
        let t = Date()
        let raul = effort(bib: 28, times: [[t, t]])
        let tony = EffortRow(overallRank: 2, genderRank: 2, bibNumber: 6,
                             firstName: "Tony", lastName: "Lehner", absoluteTimes: [[t, t]])
        let all = [tony, raul]
        XCTAssertEqual(matchEfforts("28", in: all).map { $0.bibNumber }, [28])
        XCTAssertEqual(matchEfforts("leh", in: all).map { $0.bibNumber }, [6])
        XCTAssertEqual(matchEfforts("", in: all).count, 0)
    }

    // Two THROUGH runners with the same arrival time must break the tie by bib ascending.
    func test_sortedField_throughTieBreaksByBib() {
        let h = headers(3)
        let arrival = Date(timeIntervalSince1970: 5000)
        // bib 20 arrives at the same time as bib 7; bib 7 should sort first.
        let highBib = effort(bib: 20, times: [[arrival, arrival], [arrival, arrival], [arrival, nil]])
        let lowBib  = effort(bib:  7, times: [[arrival, arrival], [arrival, arrival], [arrival, nil]])

        let ordered = sortedField([highBib, lowBib], atSplit: 2, headers: h)
        XCTAssertEqual(ordered.map { $0.bibNumber }, [7, 20])
    }

    // Within the EXPECTED group: runners sort by furthest-reached split index DESCENDING,
    // then by bib ascending on a tie.
    func test_sortedField_withinGroupOrdering() {
        let h = headers(5)
        let t = Date(timeIntervalSince1970: 1000)

        // furthest idx 2 (has a time at idx 2, none at idx 3 which is the queried split)
        let furtherA = effort(bib: 99, times: [[t, t], [t, t], [t, nil], [nil, nil], [nil, nil]])
        // furthest idx 2 same as furtherA — tie breaks by bib: 55 < 99
        let furtherB = effort(bib: 55, times: [[t, t], [t, t], [t, nil], [nil, nil], [nil, nil]])
        // furthest idx 1 — should appear after both furtherA and furtherB
        let closer   = effort(bib: 10, times: [[t, t], [t, nil], [nil, nil], [nil, nil], [nil, nil]])

        let ordered = sortedField([furtherA, closer, furtherB], atSplit: 3, headers: h)
        // All are .expected at split 3; order: furthest idx desc, then bib asc
        XCTAssertEqual(ordered.map { $0.bibNumber }, [55, 99, 10])
    }

    // matchEfforts must return results sorted by overallRank ascending, regardless of
    // the order they appear in the source array.
    func test_matchEfforts_sortsByOverallRank() {
        let t = Date()
        // Deliberately invert natural array order vs. rank order.
        let firstRank = EffortRow(overallRank: 1, genderRank: 1, bibNumber: 42,
                                  firstName: "Alpha", lastName: "Smith", absoluteTimes: [[t, t]])
        let thirdRank = EffortRow(overallRank: 3, genderRank: 2, bibNumber: 17,
                                  firstName: "Alpha", lastName: "Jones", absoluteTimes: [[t, t]])
        let secondRank = EffortRow(overallRank: 2, genderRank: 1, bibNumber: 99,
                                   firstName: "Alpha", lastName: "Brown", absoluteTimes: [[t, t]])

        // All three match "alpha"; supply them in rank-descending order to prove the sort.
        let results = matchEfforts("alpha", in: [thirdRank, firstRank, secondRank])
        XCTAssertEqual(results.map { $0.overallRank }, [1, 2, 3])
    }
}

extension RaceStatusTests {
    func test_runnerProgress_fromFixture() throws {
        let spread = try loadSpread()
        let beer = try XCTUnwrap(spread.efforts.first { $0.bibNumber == 28 })
        let progress = runnerProgress(beer, spread: spread)
        XCTAssertEqual(progress.summary.bib, "28")
        XCTAssertEqual(progress.summary.name, "Raul Beer")
        XCTAssertEqual(progress.rows.count, 18)
        // Start: one line, no label. Clock shows weekday + 12-hour, same as the field view.
        XCTAssertEqual(progress.rows[0].lines.count, 1)
        XCTAssertNil(progress.rows[0].lines[0].label)
        XCTAssertEqual(progress.rows[0].lines[0].elapsed, "0:00")
        XCTAssertEqual(progress.rows[0].lines[0].timeOfDay, "(Fri 6:00AM)")
        // Raspberry 1: In/Out → two labelled lines.
        XCTAssertEqual(progress.rows[1].lines.count, 2)
        XCTAssertEqual(progress.rows[1].lines[0].label, "In")
        XCTAssertEqual(progress.rows[1].lines[1].label, "Out")
        XCTAssertEqual(progress.rows[1].lines[0].elapsed, "1:05")
        XCTAssertEqual(progress.rows[1].lines[0].timeOfDay, "(Fri 7:05AM)")
    }

    func test_stationField_fromFixture() throws {
        let spread = try loadSpread()
        let field = stationField(splitIndex: 2, spread: spread) // Antero
        XCTAssertEqual(field.rows.count, 151)
        XCTAssertEqual(field.countText, "147 of 151 through")
        // The first row is whoever came through Antero earliest (bib 79, Fri 9:08AM).
        XCTAssertEqual(field.rows.first?.status, "Through")
        XCTAssertEqual(field.rows.first?.time, "3:08 (Fri 9:08AM)")
    }

    func test_clockWithDayFormatsWeekdayAnd12Hour() {
        let tz = mtZone()
        let friMorning = date(2022, 7, 22, 9, 8, tz: tz) // 2022-07-22 is a Friday
        XCTAssertEqual(RaceStatusFormat.clockWithDay(friMorning, in: tz), "Fri 9:08AM")
    }
}
