import XCTest
@testable import OST_Remote

final class LiveReadsFormatTests: XCTestCase {

    // MARK: clock

    func test_clock_keepsBareEnteredTime() {
        XCTAssertEqual(LiveReadsFormat.clock(enteredTime: "10:42:03", absoluteTime: nil), "10:42:03")
    }

    func test_clock_extractsTimeFromFullEnteredTimestamp() {
        // ost-remote stamps a full local datetime with offset; show only the clock.
        XCTAssertEqual(
            LiveReadsFormat.clock(enteredTime: "2022-07-12 23:58:28-6:00", absoluteTime: nil),
            "23:58:28")
    }

    func test_clock_fallsBackToAbsoluteTimeInZone() {
        // entered_time missing → render the UTC instant in the given zone.
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(
            LiveReadsFormat.clock(enteredTime: nil, absoluteTime: "2026-06-20T15:42:03.000Z", zone: utc),
            "15:42:03")
    }

    func test_clock_returnsDashWhenNothingUsable() {
        XCTAssertEqual(LiveReadsFormat.clock(enteredTime: nil, absoluteTime: nil), "—")
    }

    // MARK: friendlySource

    func test_friendlySource_ownDeviceReadsAsThisApp() {
        XCTAssertEqual(LiveReadsFormat.friendlySource("ost-remote-ABC123", myUUID: "ABC123"), "This app")
    }

    func test_friendlySource_otherRemoteDevice() {
        XCTAssertEqual(LiveReadsFormat.friendlySource("ost-remote-ZZZ999", myUUID: "ABC123"), "Remote device")
    }

    func test_friendlySource_bareOstRemoteIsRemoteDevice() {
        XCTAssertEqual(LiveReadsFormat.friendlySource("ost-remote", myUUID: "ABC123"), "Remote device")
    }

    func test_friendlySource_keepsOtherSourcesVerbatim() {
        XCTAssertEqual(LiveReadsFormat.friendlySource("Rake Task", myUUID: "ABC123"), "Rake Task")
    }

    func test_friendlySource_emptyWhenMissing() {
        XCTAssertEqual(LiveReadsFormat.friendlySource(nil, myUUID: "ABC123"), "")
    }
}
