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

    /// Posted (on the main queue) whenever the network path's reachability changes.
    @objc static let changedNotification = Notification.Name("OSTReachabilityChanged")

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "org.opensplittime.reachability")
    private var started = false
    private var _reachable = false

    @objc private(set) var isReachable: Bool {
        get { _reachable }
        set { _reachable = newValue }
    }

    @objc func start() {
        guard !started else { return }
        started = true
        _reachable = monitor.currentPath.status == .satisfied
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(reachable: path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    private func update(reachable: Bool) {
        DispatchQueue.main.async {
            guard self._reachable != reachable else { return }
            self._reachable = reachable
            NotificationCenter.default.post(name: OSTReachability.changedNotification, object: self)
        }
    }

    /// Test seam: drive a reachability change without a live network.
    @objc func _simulatePathChange(reachable: Bool) {
        let work = {
            self._reachable = reachable
            NotificationCenter.default.post(name: OSTReachability.changedNotification, object: self)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}
