import XCTest
@testable import OST_Remote

/// End-to-end test against the real OpenSplitTime API. Skipped unless
/// `OST_LIVE_TESTS=1` so the default offline suite stays deterministic.
/// Run from Xcode with scheme env vars OST_EMAIL / OST_PASSWORD set
/// (credentials in local memory; xcodebuild shell env does not reach the sim).
final class LiveAPITests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    override func setUpWithError() throws {
        try XCTSkipUnless(env["OST_LIVE_TESTS"] == "1", "live tests disabled")
    }

    func test_loginAndFetchTestEventGroup() {
        let client = APIClient(baseURL: URL(string: "https://www.opensplittime.org/api/v1/")!)
        let exp = expectation(description: "live")
        client.login(email: env["OST_EMAIL"]!, password: env["OST_PASSWORD"]!) { result in
            switch result {
            case .failure(let e): XCTFail("login failed: \(e)"); exp.fulfill()
            case .success(let auth):
                XCTAssertFalse(auth.token.isEmpty)
                client.get("event_groups/437?include=events.efforts,events.splits", as: JSONAPIDoc.self) { docResult in
                    switch docResult {
                    case .failure(let e): XCTFail("fetch failed: \(e)")
                    case .success(let doc):
                        XCTAssertEqual(doc.data.id, "437")
                        XCTAssertEqual(doc.data.attributes.name, "Test Lonesome 100")
                        let splits = doc.included.filter { $0.type == "splits" }.compactMap { $0.attributes.baseName }
                        XCTAssertTrue(splits.contains("Raspberry 1"))
                    }
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 30)
    }
}
