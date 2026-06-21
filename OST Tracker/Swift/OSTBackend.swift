//
//  OSTBackend.swift
//  OST Tracker
//
//  Swift networking service that runs the OpenSplitTime *read* endpoints through
//  `APIClient`, replacing the AFNetworking-based `OSTNetworkManager` category
//  methods one at a time (Phase 4). Each call does an autoLogin (login with the
//  stored credentials → bearer token on the client) then the request, mirroring
//  the old `getEventsDetails` behaviour. Completions are delivered on the main
//  queue with the raw parsed JSON the existing callers already expect.
//
//  The submit (write) path stays on OSTNetworkManager until its own batch.
//

import Foundation

@objc final class OSTBackend: NSObject {
    @objc static let shared = OSTBackend()

    private let client: APIClient
    private lazy var checker = ConnectivityChecker(auth: client, store: SessionCredentialStore())

    private override init() {
        let urlString = (Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String) ?? ""
        client = APIClient(baseURL: URL(string: urlString) ?? URL(string: "https://www.opensplittime.org/api/v1/")!)
        super.init()
    }

    // MARK: - Read endpoints

    @objc func getAllEvents(completion: @escaping (Any?, Error?) -> Void) {
        request("event_groups?filter[editable]=true&filter[availableLive]=true", completion: completion)
    }

    @objc func getEventsDetails(_ eventId: String, completion: @escaping (Any?, Error?) -> Void) {
        let path = "event_groups/\(eventId)?include=events.efforts&fields[efforts]=eventId,fullName,gender,age,flexibleGeolocation,bibNumber"
        request(path, completion: completion)
    }

    @objc func fetchNotExpected(groupId: String, splitName: String, completion: @escaping (Any?, Error?) -> Void) {
        let escaped = splitName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? splitName
        request("event_groups/\(groupId)/not_expected?split_name=\(escaped)", completion: completion)
    }

    /// Polls the raw_times JSON:API for the given event group + station, newest
    /// first, capped at the server max page size. Returns the parsed JSON dict
    /// (callers run it through `RawTime.parse`). Mirrors `fetchNotExpected`.
    @objc func fetchRawTimes(groupId: String,
                             splitName: String,
                             completion: @escaping (Any?, Error?) -> Void) {
        request(LiveReadsRequest.path(groupId: groupId, splitName: splitName), completion: completion)
    }

    // MARK: - Race Overview reads (typed)

    func fetchSpread(eventSlug: String,
                     completion: @escaping (Result<EventSpread, Error>) -> Void) {
        decodableRequest("events/\(eventSlug)/spread", as: EventSpread.self, completion: completion)
    }

    func fetchEvents(inGroup groupId: String,
                     completion: @escaping (Result<[EventRef], Error>) -> Void) {
        decodableRequest("event_groups/\(groupId)?include=events", as: JSONAPIDoc.self) { result in
            switch result {
            case .success(let doc):
                let refs = doc.included
                    .filter { $0.type == "events" }
                    .map { EventRef(slug: $0.attributes.slug ?? "", name: $0.attributes.name ?? "") }
                    .filter { !$0.slug.isEmpty }
                completion(.success(refs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Connectivity-checked (autologin) typed GET, decoded via `APIClient.get`,
    /// delivered on the main queue. Mirrors `request(_:completion:)` but Codable.
    private func decodableRequest<T: Decodable>(_ path: String, as type: T.Type,
                                                completion: @escaping (Result<T, Error>) -> Void) {
        checker.check { [weak self, client] loginError in
            if let loginError = loginError {
                DispatchQueue.main.async { completion(.failure(loginError)) }
                return
            }
            client.get(path, as: T.self) { result in
                if case .failure(let error) = result { self?.invalidateIfUnauthorized(error) }
                DispatchQueue.main.async { completion(result) }
            }
        }
    }

    /// A 401 on a read means the cached token went stale inside its trust window;
    /// drop it so the next request re-authenticates rather than reusing it.
    private func invalidateIfUnauthorized(_ error: Error) {
        if (error as NSError).code == 401 { checker.invalidate() }
    }

    // MARK: - Write (entry submit) — transport only

    /// POSTs an already-built JSON body to an absolute URL, off AFNetworking. The
    /// caller (Obj-C `submitEntriesToGroup`) still builds the exact same payload
    /// and passes its current bearer token, so behaviour is unchanged — only the
    /// HTTP transport moves to URLSession.
    @objc static func postJSON(toURL urlString: String,
                               authorization: String?,
                               body: [String: Any],
                               completion: @escaping (Any?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "OST", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Bad submit URL"]))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        if let authorization = authorization { req.setValue(authorization, forHTTPHeaderField: "Authorization") }
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            // Never POST an empty body on an encode failure: the server would
            // reject it with an opaque error and the real cause would be lost.
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "OST", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not encode submit payload: \(error.localizedDescription)"
                ]))
            }
            return
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { completion(nil, error); return }
                let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    completion(nil, NSError(domain: "OST", code: http.statusCode,
                                            userInfo: [NSLocalizedDescriptionKey: "Submit failed (\(http.statusCode))"]))
                    return
                }
                completion(json, nil)
            }
        }.resume()
    }

    // MARK: - Pre-logout connectivity check

    /// Active connectivity + credential check used before logout. Runs the same
    /// `ConnectivityChecker` the read endpoints use, then delivers the result on
    /// the main queue. `nil` == reachable and credentials valid (200); non-nil ==
    /// blocked.
    @objc func verifyConnection(completion: @escaping (Error?) -> Void) {
        checker.check { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    // MARK: - Plumbing

    private func request(_ path: String, completion: @escaping (Any?, Error?) -> Void) {
        checker.check { [weak self, client] loginError in
            if let loginError = loginError {
                DispatchQueue.main.async { completion(nil, loginError) }
                return
            }
            client.getJSONObject(path) { result in
                if case .failure(let error) = result { self?.invalidateIfUnauthorized(error) }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let json): completion(json, nil)
                    case .failure(let error): completion(nil, error)
                    }
                }
            }
        }
    }
}

/// The pre-auth credential check shared by `OSTBackend`'s read endpoints and the
/// pre-logout verification: read the stored credentials, then authenticate.
/// `nil` == reachable and credentials valid (200); non-nil == blocked (no stored
/// credentials, or the auth request failed). Queue-agnostic — callers hop to the
/// main queue as needed. `auth`/`store` are injectable so it is testable without
/// the network, mirroring `LoginController`.
final class ConnectivityChecker {
    private let auth: Authenticating
    private let store: CredentialStore
    /// When the current token stops being trusted. While in the future, reads
    /// reuse the existing bearer token instead of re-authenticating — live polling
    /// otherwise paid a full login round-trip before every single GET.
    private var validUntil: Date?

    /// Trust window when the auth response carries no usable expiration.
    private static let defaultCacheWindow: TimeInterval = 60
    /// Re-authenticate this long before a known expiry to avoid racing it.
    private static let expiryMargin: TimeInterval = 60
    /// Never trust a cached token longer than this regardless of a far-future
    /// expiration — guards against clock skew / early server-side invalidation.
    private static let maxCacheWindow: TimeInterval = 600

    init(auth: Authenticating, store: CredentialStore) {
        self.auth = auth
        self.store = store
    }

    func check(completion: @escaping (Error?) -> Void) {
        guard let email = store.email, !email.isEmpty,
              let password = store.password, !password.isEmpty else {
            validUntil = nil
            completion(NSError(domain: "OST", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "Missing stored credentials. Please log in again."]))
            return
        }
        if let validUntil = validUntil, validUntil > Date() {
            completion(nil) // still-valid token; skip the re-auth round-trip
            return
        }
        auth.authenticate(email: email, password: password) { [weak self] result in
            switch result {
            case .success(let response):
                self?.validUntil = ConnectivityChecker.cacheExpiry(from: response.expiration)
                completion(nil)
            case .failure(let error):
                self?.validUntil = nil
                completion(error)
            }
        }
    }

    /// Drop the cached token so the next `check` re-authenticates. Call when a read
    /// is rejected for auth (401): the token went stale inside its trust window.
    func invalidate() { validUntil = nil }

    private static func cacheExpiry(from expiration: String?, now: Date = Date()) -> Date {
        let cap = now.addingTimeInterval(maxCacheWindow)
        guard let expiration = expiration,
              let expiry = iso.date(from: expiration) ?? isoFractional.date(from: expiration) else {
            return now.addingTimeInterval(defaultCacheWindow)
        }
        return min(expiry.addingTimeInterval(-expiryMargin), cap)
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
}
