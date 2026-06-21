import XCTest
@testable import OST_Remote

final class APIParsingTests: XCTestCase {
    func test_parsesEventGroupsList() throws {
        let list = try JSONDecoder().decode(JSONAPIList.self, from: Fixture.data("event_groups_list"))
        let names = list.data.compactMap { $0.attributes.name }
        XCTAssertTrue(names.contains("Test Lonesome 100"), "got: \(names)")
        XCTAssertTrue(list.data.allSatisfy { $0.type == "eventGroups" })
    }

    func test_parsesEventGroupSplits() throws {
        let doc = try JSONDecoder().decode(JSONAPIDoc.self, from: Fixture.data("event_group_437"))
        XCTAssertEqual(doc.data.id, "437")
        let splits = doc.included.filter { $0.type == "splits" }.compactMap { $0.attributes.baseName }
        XCTAssertTrue(splits.contains("Raspberry 1"), "got: \(splits)")
    }

    func test_parsesAuthResponseShape() throws {
        let auth = try JSONDecoder().decode(AuthResponse.self, from: Fixture.data("auth_response"))
        XCTAssertEqual(auth.token, "<<REDACTED_TOKEN>>")
    }

    // MARK: - SpreadDate.timeZone offset parsing

    func test_timeZone_parsesZuluAsUTC() {
        XCTAssertEqual(SpreadDate.timeZone(from: "2026-06-20T10:00:00Z").secondsFromGMT(), 0)
    }

    func test_timeZone_parsesPositiveAndNegativeWholeHours() {
        XCTAssertEqual(SpreadDate.timeZone(from: "2026-06-20T10:00:00-06:00").secondsFromGMT(), -6 * 3600)
        XCTAssertEqual(SpreadDate.timeZone(from: "2026-06-20T10:00:00+05:00").secondsFromGMT(), 5 * 3600)
    }

    func test_timeZone_appliesSignToMinutes() {
        // Half-hour zones: the sign must apply to the minutes too.
        XCTAssertEqual(SpreadDate.timeZone(from: "2026-06-20T10:00:00+05:30").secondsFromGMT(), 5 * 3600 + 30 * 60)
        XCTAssertEqual(SpreadDate.timeZone(from: "2026-06-20T10:00:00-09:30").secondsFromGMT(), -(9 * 3600 + 30 * 60))
    }

    func test_timeZone_negativeSubHourOffsetKeepsSign() {
        // Regression: "-00:30" has hours == 0, so inferring the sign from the hour
        // (the old bug) yielded +30min instead of -30min.
        XCTAssertEqual(SpreadDate.timeZone(from: "2026-06-20T10:00:00-00:30").secondsFromGMT(), -30 * 60)
    }
}
