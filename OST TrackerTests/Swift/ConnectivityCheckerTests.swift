import XCTest
@testable import OST_Remote

/// `ConnectivityChecker` is the shared pre-auth check behind both the read
/// endpoints and the pre-logout verification. These tests pin its decision
/// mapping without touching the network, using the same `Authenticating` /
/// `CredentialStore` seams `LoginController` is tested through.
private final class StubAuth: Authenticating {
    var result: Result<AuthResponse, Error> = .failure(URLError(.unknown))
    private(set) var calledWith: (String, String)?
    private(set) var callCount = 0
    func authenticate(email: String, password: String,
                      completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        calledWith = (email, password)
        callCount += 1
        completion(result)
    }
}

private final class StubStore: CredentialStore {
    private var storedEmail: String?
    private var storedPassword: String?
    init(email: String?, password: String?) { storedEmail = email; storedPassword = password }
    func save(email: String, password: String) { storedEmail = email; storedPassword = password }
    var email: String? { storedEmail }
    var password: String? { storedPassword }
}

final class ConnectivityCheckerTests: XCTestCase {
    /// 200 (auth succeeds) → reachable: a nil error, and the stored credentials
    /// are the ones authenticated with.
    func test_authSuccess_returnsNilError() {
        let auth = StubAuth(); auth.result = .success(AuthResponse(token: "tok", expiration: nil))
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: "a@b.com", password: "pw"))

        let exp = expectation(description: "check")
        var receivedError: Error?
        sut.check { error in receivedError = error; exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertNil(receivedError, "a successful auth should yield a nil error")
        XCTAssertEqual(auth.calledWith?.0, "a@b.com")
        XCTAssertEqual(auth.calledWith?.1, "pw")
    }

    /// Auth failure (non-200 / network error) → blocked: the underlying error is
    /// passed through unchanged so the caller can route to the override path.
    func test_authFailure_passesErrorThrough() {
        let auth = StubAuth(); auth.result = .failure(URLError(.notConnectedToInternet))
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: "a@b.com", password: "pw"))

        let exp = expectation(description: "check")
        var receivedError: Error?
        sut.check { error in receivedError = error; exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual((receivedError as? URLError)?.code, .notConnectedToInternet,
                       "the auth failure should pass through unchanged")
    }

    /// No stored credentials → blocked without ever hitting the network.
    func test_missingCredentials_returnsError_withoutAuthenticating() {
        let auth = StubAuth()
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: nil, password: nil))

        let exp = expectation(description: "check")
        var receivedError: Error?
        sut.check { error in receivedError = error; exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual((receivedError as NSError?)?.domain, "OST")
        XCTAssertEqual((receivedError as NSError?)?.code, 401, "missing credentials must yield the 401 'please log in again' error")
        XCTAssertNil(auth.calledWith, "must not authenticate when credentials are missing")
    }

    /// Blank (empty-string) credentials are treated the same as missing.
    func test_blankCredentials_treatedAsMissing() {
        let auth = StubAuth()
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: "", password: ""))

        let exp = expectation(description: "check")
        var receivedError: Error?
        sut.check { error in receivedError = error; exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertEqual((receivedError as NSError?)?.code, 401, "blank credentials must be treated as missing (same 401)")
        XCTAssertNil(auth.calledWith, "must not authenticate with blank credentials")
    }

    // MARK: - Token caching

    private func check(_ sut: ConnectivityChecker) {
        let exp = expectation(description: "check")
        sut.check { _ in exp.fulfill() }
        wait(for: [exp], timeout: 1)
    }

    /// A still-valid token is reused: the second read skips the auth round-trip.
    func test_validToken_skipsReauthWithinWindow() {
        let auth = StubAuth(); auth.result = .success(AuthResponse(token: "tok", expiration: nil))
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: "a@b.com", password: "pw"))
        check(sut); check(sut)
        XCTAssertEqual(auth.callCount, 1, "second read within the trust window must not re-authenticate")
    }

    /// invalidate() drops the cache so the next read authenticates again.
    func test_invalidate_forcesReauth() {
        let auth = StubAuth(); auth.result = .success(AuthResponse(token: "tok", expiration: nil))
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: "a@b.com", password: "pw"))
        check(sut)
        sut.invalidate()
        check(sut)
        XCTAssertEqual(auth.callCount, 2, "a stale token (invalidate) must re-authenticate")
    }

    /// Switching users must not reuse the previous user's token. When the stored
    /// credentials change to a different user inside the old trust window (log out
    /// as A, log in as B, then fetch events), the read must re-authenticate as B
    /// rather than serving A's data with A's cached bearer token.
    func test_credentialChange_forcesReauth() {
        let auth = StubAuth(); auth.result = .success(AuthResponse(token: "tokA", expiration: nil))
        let store = StubStore(email: "a@b.com", password: "pwA")
        let sut = ConnectivityChecker(auth: auth, store: store)
        check(sut)
        XCTAssertEqual(auth.callCount, 1)

        store.save(email: "b@b.com", password: "pwB") // user B logs in, within A's window
        check(sut)
        XCTAssertEqual(auth.callCount, 2, "a change of stored user must force re-authentication")
        XCTAssertEqual(auth.calledWith?.0, "b@b.com", "must re-authenticate as the new user")
    }

    /// A failed auth is never cached: the next read tries again.
    func test_authFailure_isNotCached() {
        let auth = StubAuth(); auth.result = .failure(URLError(.timedOut))
        let sut = ConnectivityChecker(auth: auth, store: StubStore(email: "a@b.com", password: "pw"))
        check(sut); check(sut)
        XCTAssertEqual(auth.callCount, 2, "a failed auth must not be cached")
    }
}
