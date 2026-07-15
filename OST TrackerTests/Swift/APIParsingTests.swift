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

    // MARK: - EntryTimeFormat.absoluteTime

    func test_entryTimeFormat_preservesHalfHourAndPadsNegativeSign() {
        let india = TimeZone(secondsFromGMT: 5 * 3600 + 30 * 60)!   // +05:30
        XCTAssertTrue(EntryTimeFormat.absoluteTime(day: Date(), timeOfDay: "10:00:00", timeZone: india)
                        .hasSuffix("10:00:00+05:30"), "half-hour zones must keep their minutes")

        let utcMinus6 = TimeZone(secondsFromGMT: -6 * 3600)!        // -06:00 (old code emitted "-6:00")
        XCTAssertTrue(EntryTimeFormat.absoluteTime(day: Date(), timeOfDay: "10:00:00", timeZone: utcMinus6)
                        .hasSuffix("10:00:00-06:00"), "negative whole-hour offset must be zero-padded")

        let utc = TimeZone(secondsFromGMT: 0)!
        XCTAssertTrue(EntryTimeFormat.absoluteTime(day: Date(), timeOfDay: "09:00:00", timeZone: utc)
                        .hasSuffix("09:00:00+00:00"))
    }

    // MARK: - APIClient transport (URLProtocol-stubbed, no network)

    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return APIClient(baseURL: URL(string: "https://example.test/api/v1/")!,
                         session: URLSession(configuration: config))
    }

    override func tearDown() { StubURLProtocol.stub = nil; super.tearDown() }

    func test_getJSONObject_non2xx_surfacesServerBody() {
        let body = #"{"errors":["Invalid email or password"]}"#
        StubURLProtocol.stub = .init(statusCode: 401, data: Data(body.utf8), error: nil)

        let exp = expectation(description: "get")
        var nsError: NSError?
        makeClient().getJSONObject("auth") { result in
            if case .failure(let e) = result { nsError = e as NSError }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual(nsError?.code, 401)
        let raw = nsError?.userInfo[APIClient.responseDataErrorKey] as? Data
        XCTAssertEqual(raw.flatMap { String(data: $0, encoding: .utf8) }, body,
                       "the server's error body must be attached so errorsFromDictionary can surface it")
    }

    func test_getJSONObject_success_returnsParsedDict() {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(#"{"data":{"id":"7"}}"#.utf8), error: nil)
        let exp = expectation(description: "get")
        var dict: [String: Any]?
        makeClient().getJSONObject("event_groups/7") { result in
            if case .success(let json) = result { dict = json }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual((dict?["data"] as? [String: Any])?["id"] as? String, "7")
    }

    func test_get_decodeFailure_propagates() {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data("not json".utf8), error: nil)
        let exp = expectation(description: "get")
        var failed = false
        makeClient().get("auth", as: AuthResponse.self) { result in
            if case .failure = result { failed = true }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(failed, "a body that doesn't decode into T must propagate a failure")
    }

    func test_login_setsTokenAndDeliversOnMainQueue() {
        StubURLProtocol.stub = .init(statusCode: 200, data: Data(#"{"token":"abc123"}"#.utf8), error: nil)
        let client = makeClient()
        let exp = expectation(description: "login")
        var onMain = false
        client.login(email: "a@b.com", password: "pw") { _ in
            onMain = Thread.isMainThread
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(client.token, "abc123", "a successful login stores the bearer token")
        XCTAssertTrue(onMain, "completions are delivered on the main queue")
    }

    func test_postJSON_nonSerializableBody_failsWithoutNetwork() {
        // Date is not a valid JSON value, so encoding throws — postJSON must fail
        // the completion rather than POST an empty body.
        let exp = expectation(description: "post")
        var nsError: NSError?
        OSTBackend.postJSON(toURL: "https://example.test/submit", authorization: nil,
                            body: ["when": Date()]) { _, error in
            nsError = error as NSError?
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertNotNil(nsError, "a non-serializable body must fail, not send an empty POST")
    }
}

/// URLProtocol that returns a canned response so APIClient can be exercised
/// without the network. Set `stub` before each call.
private final class StubURLProtocol: URLProtocol {
    struct Stub { let statusCode: Int; let data: Data?; let error: Error? }
    static var stub: Stub?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        if let error = StubURLProtocol.stub?.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let stub = StubURLProtocol.stub ?? Stub(statusCode: 200, data: nil, error: nil)
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.statusCode,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = stub.data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }
}
