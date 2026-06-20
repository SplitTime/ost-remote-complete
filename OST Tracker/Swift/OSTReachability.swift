//
//  OSTReachability.swift
//  OST Tracker
//
//  Native network reachability (NWPathMonitor, iOS 12+), replacing AFNetworking's
//  reachabilityManager. Used by the Utilities logout guard.
//

import Foundation
import Network

@objc final class OSTReachability: NSObject {
    @objc static let shared = OSTReachability()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "org.opensplittime.reachability")
    private var started = false

    @objc var isReachable: Bool { monitor.currentPath.status == .satisfied }

    @objc func start() {
        guard !started else { return }
        started = true
        monitor.start(queue: queue)
    }
}
