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
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

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
    /// `autoLogin` (POST `auth` with stored credentials) the read endpoints use.
    /// `nil` == reachable and credentials valid (200); non-nil == blocked.
    /// Completion is delivered on the main queue.
    @objc func verifyConnection(completion: @escaping (Error?) -> Void) {
        autoLogin { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    // MARK: - Plumbing

    private func request(_ path: String, completion: @escaping (Any?, Error?) -> Void) {
        autoLogin { [client] loginError in
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

    /// Login with the stored credentials so the client holds a fresh bearer token.
    private func autoLogin(_ completion: @escaping (Error?) -> Void) {
        let email = OSTSessionManager.getStoredUserName() ?? ""
        let password = OSTSessionManager.getStoredPassword() ?? ""
        guard !email.isEmpty, !password.isEmpty else {
            completion(NSError(domain: "OST", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "Missing stored credentials. Please log in again."]))
            return
        }
        client.login(email: email, password: password) { result in
            switch result {
            case .success: completion(nil)
            case .failure(let error): completion(error)
            }
        }
    }
}
