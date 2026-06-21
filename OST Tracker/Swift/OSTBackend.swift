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

    // MARK: - Race Status reads (typed)

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
        checker.check { [client] loginError in
            if let loginError = loginError {
                DispatchQueue.main.async { completion(.failure(loginError)) }
                return
            }
            client.get(path, as: T.self) { result in
                DispatchQueue.main.async { completion(result) }
            }
        }
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
        checker.check { [client] loginError in
            if let loginError = loginError {
                DispatchQueue.main.async { completion(nil, loginError) }
                return
            }
            client.getJSONObject(path) { result in
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

    init(auth: Authenticating, store: CredentialStore) {
        self.auth = auth
        self.store = store
    }

    func check(completion: @escaping (Error?) -> Void) {
        guard let email = store.email, !email.isEmpty,
              let password = store.password, !password.isEmpty else {
            completion(NSError(domain: "OST", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "Missing stored credentials. Please log in again."]))
            return
        }
        auth.authenticate(email: email, password: password) { result in
            switch result {
            case .success: completion(nil)
            case .failure(let error): completion(error)
            }
        }
    }
}
