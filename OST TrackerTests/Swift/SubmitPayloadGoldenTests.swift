import XCTest
@testable import OST_Remote

final class SubmitPayloadGoldenTests: XCTestCase {
    func test_liveTimePayloadMatchesGolden() throws {
        let entry = LiveTimeEntry(bibNumber: "42", splitId: "900", subSplitKind: "in",
                                  enteredTime: "2026-06-16T10:14:22-06:00",
                                  withPacer: "false", stoppedHere: "false",
                                  source: "ost-remote-ios")
        let built = LiveTimeEntry.eventImportPayload([entry])

        let golden = try JSONSerialization.jsonObject(with: Fixture.data("submit_live_time_golden")) as! NSDictionary
        XCTAssertEqual(built as NSDictionary, golden)
    }
}
