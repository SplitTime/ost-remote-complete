import XCTest
@testable import OST_Remote

/// `ConnectivityChecker` is the shared pre-auth check behind both the read
/// endpoints and the pre-logout verification. These tests pin its decision
/// mapping without touching the network, using the same `Authenticating` /
/// `CredentialStore` seams `LoginController` is tested through.
private final class StubAuth: Authenticating {
    var result: Result<AuthResponse, Error> = .failure(URLError(.unknown))
    private(set) var calledWith: (String, String)?
    func authenticate(email: String, password: String,
                      completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        calledWith = (email, password)
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
        var completed = false
        var receivedError: Error?
        sut.check { error in receivedError = error; completed = true; exp.fulfill() }
        wait(for: [exp], timeout: 1)

        XCTAssertTrue(completed)
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

        XCTAssertNotNil(receivedError, "missing credentials must be blocked")
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

        XCTAssertNotNil(receivedError, "blank credentials must be treated as missing")
        XCTAssertNil(auth.calledWith, "must not authenticate with blank credentials")
    }
}
