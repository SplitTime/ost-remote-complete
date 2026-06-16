import Foundation

/// Async URLSession client reproducing the OpenSplitTime API contract that the
/// old AFNetworking-based `OSTNetworkManager` spoke. Endpoints are added as the
/// migration needs them.
final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private(set) var token: String?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// `POST auth` with form-encoded credentials; stores the bearer token.
    @discardableResult
    func login(email: String, password: String) async throws -> AuthResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        let body = "user[email]=\(email.formURLEncoded)&user[password]=\(password.formURLEncoded)"
        req.httpBody = body.data(using: .utf8)

        let (data, _) = try await session.data(for: req)
        let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
        token = auth.token
        return auth
    }

    /// Authenticated GET decoding into `T`. `path` is relative to the base URL
    /// and may include a query string.
    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        if let token { req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private extension String {
    /// Matches AFNetworking's form encoding for the login body.
    var formURLEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._* ")
        let escaped = addingPercentEncoding(withAllowedCharacters: allowed) ?? self
        return escaped.replacingOccurrences(of: " ", with: "+")
    }
}
