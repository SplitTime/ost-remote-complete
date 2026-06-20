// OST Tracker/Swift/AutoSync/AutoSyncEngine.swift
import Foundation

/// Pure auto-sync state machine. No Core Data, no network, no UIKit — every
/// side effect is an injected closure, so the whole thing is unit-testable.
final class AutoSyncEngine {
    private let scheduler: AutoSyncScheduler
    private let pendingCount: () -> Int
    private let isReachable: () -> Bool
    private let performSync: (@escaping (Result<Void, Error>) -> Void) -> Void
    private let onStatusChange: (AutoSyncStatus) -> Void
    private let debounceSeconds: TimeInterval
    private let backoff: [TimeInterval] = [5, 15, 30, 60]

    private var enabled: Bool
    private(set) var isSyncing = false
    private var active = true
    private var lastSyncDate: Date?
    private var backoffIndex = 0
    private var debounceToken: AutoSyncCancellable?
    private var retryToken: AutoSyncCancellable?
    private var lastPublished: AutoSyncStatus?

    init(enabled: Bool, debounceSeconds: TimeInterval = 3,
         scheduler: AutoSyncScheduler,
         pendingCount: @escaping () -> Int,
         isReachable: @escaping () -> Bool,
         performSync: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void,
         onStatusChange: @escaping (AutoSyncStatus) -> Void) {
        self.enabled = enabled
        self.debounceSeconds = debounceSeconds
        self.scheduler = scheduler
        self.pendingCount = pendingCount
        self.isReachable = isReachable
        self.performSync = performSync
        self.onStatusChange = onStatusChange
    }

    var currentStatus: AutoSyncStatus {
        let count = pendingCount()
        let state: AutoSyncState
        if !enabled { state = .disabled }
        else if isSyncing { state = .syncing }
        else if count == 0 { state = .synced }
        else if !isReachable() { state = .offline }
        else if backoffIndex > 0 { state = .failed }
        else { state = .pending }
        return AutoSyncStatus(state: state, pendingCount: count, lastSyncDate: lastSyncDate)
    }

    // MARK: - External events

    func setEnabled(_ on: Bool) {
        enabled = on
        if on {
            publish()
            if pendingCount() > 0 { attemptSync() }
        } else {
            cancelTimers()
            backoffIndex = 0
            publish()
        }
    }

    func noteEntriesChanged() {
        guard enabled, active else { return }
        publish() // reflect new pending count immediately
        debounceToken?.cancel()
        debounceToken = scheduler.schedule(after: debounceSeconds) { [weak self] in
            self?.debounceToken = nil
            self?.attemptSync()
        }
    }

    func reachabilityChanged() {
        guard enabled, active else { publish(); return }
        if isReachable(), pendingCount() > 0 { attemptSync() } else { publish() }
    }

    func enterForeground() {
        active = true
        if enabled, pendingCount() > 0 { attemptSync() } else { publish() }
    }

    func enterBackground() {
        active = false
        cancelTimers()
    }

    func forceRetry() {
        guard enabled, active else { return }
        attemptSync()
    }

    // MARK: - Core

    private func attemptSync() {
        guard enabled, active, !isSyncing, pendingCount() > 0 else { publish(); return }
        guard isReachable() else { publish(); return } // .offline; waits for reachability/forceRetry
        retryToken?.cancel(); retryToken = nil
        isSyncing = true
        publish()
        performSync { [weak self] result in
            guard let self = self else { return }
            self.isSyncing = false
            switch result {
            case .success:
                self.lastSyncDate = Date()
                self.backoffIndex = 0
                self.publish()
                if self.pendingCount() > 0 { self.scheduleRetry() } // more arrived mid-sync
            case .failure:
                self.publish()
                self.scheduleRetry()
            }
        }
    }

    private func scheduleRetry() {
        guard enabled, active, pendingCount() > 0 else { return }
        let delay = backoff[min(backoffIndex, backoff.count - 1)]
        backoffIndex = min(backoffIndex + 1, backoff.count)
        retryToken?.cancel()
        retryToken = scheduler.schedule(after: delay) { [weak self] in
            self?.retryToken = nil
            self?.attemptSync()
        }
    }

    private func cancelTimers() {
        debounceToken?.cancel(); debounceToken = nil
        retryToken?.cancel(); retryToken = nil
    }

    private func publish() {
        let s = currentStatus
        guard s != lastPublished else { return }
        lastPublished = s
        onStatusChange(s)
    }
}
