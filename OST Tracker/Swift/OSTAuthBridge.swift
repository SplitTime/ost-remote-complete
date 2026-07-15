//
//  OSTAuthBridge.swift
//  OST Tracker
//
//  Lets the legacy Obj-C network layer perform the `auth` login POST through the
//  Swift `APIClient` instead of AFNetworking. AFNetworking's form-encoding of the
//  credentials was being rejected by the server ("Invalid email or password") on
//  autoLogin, even though those exact stored credentials logged the user in via
//  APIClient. Routing the login through the proven APIClient path fixes both the
//  Refresh-Data 400 and the logout false-"disabled" (both go through autoLogin).
//

import Foundation

@objc final class OSTAuthBridge: NSObject {

    /// POST `auth` with the given credentials via APIClient. Calls back with the
    /// bearer token on success, or an NSError on failure. Base URL is resolved by
    /// the shared `OSTBackend.backendBaseURL` (the same source the read endpoints
    /// use), so a missing/malformed `BACKEND_URL` falls back to production rather
    /// than failing differently here than everywhere else.
    @objc static func login(email: String,
                            password: String,
                            completion: @escaping (String?, Error?) -> Void) {
        APIClient(baseURL: OSTBackend.backendBaseURL).login(email: email, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let auth): completion(auth.token, nil)
                case .failure(let error): completion(nil, error)
                }
            }
        }
    }
}
