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
    /// bearer token on success, or an NSError on failure. Base URL comes from the
    /// app's `BACKEND_URL` Info.plist value (same one OSTNetworkManager uses).
    @objc static func login(email: String,
                            password: String,
                            completion: @escaping (String?, Error?) -> Void) {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String,
              let baseURL = URL(string: urlString) else {
            completion(nil, NSError(domain: "OST", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Missing BACKEND_URL"]))
            return
        }
        APIClient(baseURL: baseURL).login(email: email, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let auth): completion(auth.token, nil)
                case .failure(let error): completion(nil, error)
                }
            }
        }
    }
}
