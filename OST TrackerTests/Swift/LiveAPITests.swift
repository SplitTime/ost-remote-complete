import XCTest
@testable import OST_Remote

/// End-to-end test against the real OpenSplitTime API. Skipped unless
/// `OST_LIVE_TESTS=1` so the default offline suite stays deterministic.
/// Run with: OST_LIVE_TESTS=1 OST_EMAIL=… OST_PASSWORD=… (credentials in memory).
final class LiveAPITests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    override func setUpWithError() throws {
        try XCTSkipUnless(env["OST_LIVE_TESTS"] == "1", "live tests disabled")
    }

    func test_loginAndFetchTestEventGroup() async throws {
        let client = APIClient(baseURL: URL(string: "https://www.opensplittime.org/api/v1/")!)
        let auth = try await client.login(email: env["OST_EMAIL"]!, password: env["OST_PASSWORD"]!)
        XCTAssertFalse(auth.token.isEmpty)

        let doc: JSONAPIDoc = try await client.get(
            "event_groups/437?include=events.efforts,events.splits", as: JSONAPIDoc.self)
        XCTAssertEqual(doc.data.id, "437")
        XCTAssertEqual(doc.data.attributes.name, "Test Lonesome 100")
        let splits = doc.included.filter { $0.type == "splits" }.compactMap { $0.attributes.baseName }
        XCTAssertTrue(splits.contains("Raspberry 1"))
    }
}
