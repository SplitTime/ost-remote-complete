import Foundation

/// Completion-handler URLSession client reproducing the OpenSplitTime API contract
/// the old AFNetworking-based `OSTNetworkManager` spoke. iOS 12 compatible
/// (no async/await). Endpoints are added as the migration needs them.
final class APIClient {
    enum APIError: Error { case badURL, emptyResponse }

    /// AFNetworking's response-body key, kept so the legacy
    /// `NSError.errorsFromDictionary` reader still finds the raw server body and
    /// can surface the API's own error message.
    static let responseDataErrorKey = "com.alamofire.serialization.response.error.data"

    private let baseURL: URL
    private let session: URLSession
    private(set) var token: String?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// `POST auth` with form-encoded credentials; stores the bearer token on success.
    @discardableResult
    func login(email: String,
               password: String,
               completion: @escaping (Result<AuthResponse, Error>) -> Void) -> URLSessionDataTask {
        var req = URLRequest(url: baseURL.appendingPathComponent("auth"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        let body = "user[email]=\(email.formURLEncoded)&user[password]=\(password.formURLEncoded)"
        req.httpBody = body.data(using: .utf8)

        let task = decoding(req, as: AuthResponse.self) { [weak self] result in
            if case .success(let auth) = result { self?.token = auth.token }
            completion(result)
        }
        task.resume()
        return task
    }

    /// Authenticated GET decoding into `T`. `path` is relative to the base URL and
    /// may include a query string.
    @discardableResult
    func get<T: Decodable>(_ path: String,
                           as type: T.Type,
                           completion: @escaping (Result<T, Error>) -> Void) -> URLSessionDataTask? {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            completion(.failure(APIError.badURL)); return nil
        }
        var req = URLRequest(url: url)
        if let token = token { req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        let task = decoding(req, as: T.self, completion: completion)
        task.resume()
        return task
    }

    /// Authenticated GET returning the parsed JSON object (the legacy Obj-C
    /// callers consume raw `[String: Any]`, e.g. `object["data"]["attributes"]`).
    /// `[`/`]` in the query (Rails `filter[...]`/`fields[...]`) are percent-encoded
    /// so `URL(string:)` accepts them. Non-2xx is surfaced as an error.
    @discardableResult
    func getJSONObject(_ path: String,
                       completion: @escaping (Result<[String: Any], Error>) -> Void) -> URLSessionDataTask? {
        let encoded = path.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")
        guard let url = URL(string: encoded, relativeTo: baseURL) else {
            completion(.failure(APIError.badURL)); return nil
        }
        var req = URLRequest(url: url)
        if let token = token { req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        let task = session.dataTask(with: req) { data, response, error in
            let result: Result<[String: Any], Error>
            if let error = error {
                result = .failure(error)
            } else if let httpError = APIClient.httpError(from: response, data: data) {
                result = .failure(httpError)
            } else if let data = data,
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                result = .success(json)
            } else {
                result = .failure(APIError.emptyResponse)
            }
            APIClient.deliver(result, to: completion)
        }
        task.resume()
        return task
    }

    private func decoding<T: Decodable>(_ request: URLRequest,
                                        as type: T.Type,
                                        completion: @escaping (Result<T, Error>) -> Void) -> URLSessionDataTask {
        session.dataTask(with: request) { data, response, error in
            let result: Result<T, Error>
            if let error = error {
                result = .failure(error)
            } else if let httpError = APIClient.httpError(from: response, data: data) {
                result = .failure(httpError)
            } else if let data = data {
                do { result = .success(try JSONDecoder().decode(T.self, from: data)) }
                catch { result = .failure(error) }
            } else {
                result = .failure(APIError.emptyResponse)
            }
            APIClient.deliver(result, to: completion)
        }
    }

    /// Maps a non-2xx response to an error carrying the server's own body, so
    /// callers surface the API's real message instead of a generic status string.
    /// Returns nil for 2xx responses or anything that isn't an HTTP response.
    private static func httpError(from response: URLResponse?, data: Data?) -> NSError? {
        guard let http = response as? HTTPURLResponse,
              !(200..<300).contains(http.statusCode) else { return nil }
        var info: [String: Any] = [
            NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
        ]
        if let data = data { info[responseDataErrorKey] = data }
        return NSError(domain: "OST", code: http.statusCode, userInfo: info)
    }

    /// All completions are delivered on the main queue so callers never have to
    /// remember to hop — UI and Core Data work in handlers is then always safe.
    private static func deliver<T>(_ result: Result<T, Error>,
                                   to completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.main.async { completion(result) }
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
