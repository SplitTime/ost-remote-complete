import XCTest
@testable import OST_Remote

private final class StubAuth: Authenticating {
    var result: Result<AuthResponse, Error> = .failure(URLError(.unknown))
    private(set) var calledWith: (String, String)?
    func authenticate(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        calledWith = (email, password)
        completion(result)
    }
}

private final class SpyStore: CredentialStore {
    private(set) var saved: (String, String)?
    func save(email: String, password: String) { saved = (email, password) }
    var email: String? { saved?.0 }
    var password: String? { saved?.1 }
}

final class LoginControllerTests: XCTestCase {
    func test_success_storesCredentialsAndReturnsAuth() {
        let auth = StubAuth(); auth.result = .success(AuthResponse(token: "tok", expiration: nil))
        let store = SpyStore()
        let sut = LoginController(auth: auth, store: store)

        let exp = expectation(description: "login")
        sut.login(email: "a@b.com", password: "pw") { result in
            if case .success(let resp) = result { XCTAssertEqual(resp.token, "tok") } else { XCTFail("expected success") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(auth.calledWith?.0, "a@b.com")
        XCTAssertEqual(store.saved?.0, "a@b.com")
        XCTAssertEqual(store.saved?.1, "pw")
    }

    func test_failure_doesNotStoreCredentials() {
        let auth = StubAuth(); auth.result = .failure(URLError(.userAuthenticationRequired))
        let store = SpyStore()
        let sut = LoginController(auth: auth, store: store)

        let exp = expectation(description: "login")
        sut.login(email: "a@b.com", password: "pw") { result in
            if case .failure = result {} else { XCTFail("expected failure") }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        XCTAssertNil(store.saved)
    }
}
