import Foundation

/// Authentication abstraction so `LoginController` is testable without the network.
/// Named `authenticate` (not `login`) to avoid colliding with `APIClient.login`.
protocol Authenticating {
    func authenticate(email: String, password: String,
                      completion: @escaping (Result<AuthResponse, Error>) -> Void)
}

extension APIClient: Authenticating {
    func authenticate(email: String, password: String,
                     completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        login(email: email, password: password, completion: completion)
    }
}

/// Persists the user's credentials (so they prefill / enable auto-login).
protocol CredentialStore {
    func save(email: String, password: String)
    var email: String? { get }
    var password: String? { get }
}

/// Backed by the existing Obj-C `OSTSessionManager` (bridged), preserving the
/// old app's credential storage exactly.
final class SessionCredentialStore: CredentialStore {
    func save(email: String, password: String) {
        OSTSessionManager.setUserName(email, andPassword: password)
    }
    var email: String? { OSTSessionManager.getStoredUserName() }
    var password: String? { OSTSessionManager.getStoredPassword() }
}

/// Login flow logic: authenticate, and on success persist credentials. Mirrors
/// `OSTLoginViewController`'s success path (token handling is done by the view,
/// which also forwards the token to the legacy network manager until event
/// selection is migrated).
final class LoginController {
    private let auth: Authenticating
    private let store: CredentialStore

    init(auth: Authenticating, store: CredentialStore) {
        self.auth = auth
        self.store = store
    }

    /// Returns the `AuthResponse` on success (so the caller can forward the token).
    func login(email: String, password: String,
               completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        auth.authenticate(email: email, password: password) { [store] result in
            if case .success = result {
                store.save(email: email, password: password)
            }
            completion(result)
        }
    }
}
