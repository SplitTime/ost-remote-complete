// OST Tracker/Swift/AutoSync/AutoSyncEngine.swift
import Foundation

/// Outcome of a sync attempt, as classified by the production wiring from the
/// submit `Result`/error. The engine derives its `Offline`/`Failed` state from
/// this rather than from a reachability probe.
enum SyncOutcome { case success, offline, failed }

/// Pure auto-sync state machine. No Core Data, no network, no UIKit — every
/// side effect is an injected closure, so the whole thing is unit-testable.
final class AutoSyncEngine {
    private let scheduler: AutoSyncScheduler
    private let pendingCount: () -> Int
    private let performSync: (@escaping (SyncOutcome) -> Void) -> Void
    private let onStatusChange: (AutoSyncStatus) -> Void
    private let debounceSeconds: TimeInterval
    private let backoff: [TimeInterval] = [5, 15, 30, 60]

    private var enabled: Bool
    private(set) var isSyncing = false
    private var active = true
    private var lastSyncDate: Date?
    private var backoffIndex = 0
    /// Kind of the last failed attempt (nil, `.offline`, or `.failed`); drives
    /// the resting state when there are pending entries we couldn't submit.
    private var lastFailure: AutoSyncState?
    private var debounceToken: AutoSyncCancellable?
    private var retryToken: AutoSyncCancellable?
    private var lastPublished: AutoSyncStatus?

    init(enabled: Bool, debounceSeconds: TimeInterval = 3,
         scheduler: AutoSyncScheduler,
         pendingCount: @escaping () -> Int,
         performSync: @escaping (@escaping (SyncOutcome) -> Void) -> Void,
         onStatusChange: @escaping (AutoSyncStatus) -> Void) {
        self.enabled = enabled
        self.debounceSeconds = debounceSeconds
        self.scheduler = scheduler
        self.pendingCount = pendingCount
        self.performSync = performSync
        self.onStatusChange = onStatusChange
    }

    var currentStatus: AutoSyncStatus {
        // When disabled the state is always `.disabled` and the pending count is
        // purely informational; skip the Core Data fetch so a reachability/lifecycle
        // publish can never touch the store before auto-sync is turned on.
        guard enabled else { return AutoSyncStatus(state: .disabled, pendingCount: 0, lastSyncDate: lastSyncDate) }
        let count = pendingCount()
        let state: AutoSyncState
        if isSyncing { state = .syncing }
        else if count == 0 { state = .synced }
        else if lastFailure == .offline { state = .offline }
        else if lastFailure == .failed { state = .failed }
        else { state = .pending }
        return AutoSyncStatus(state: state, pendingCount: count, lastSyncDate: lastSyncDate)
    }

    // MARK: - External events

    func setEnabled(_ on: Bool) {
        enabled = on
        if on {
            lastFailure = nil // re-enabling shouldn't surface a stale failure
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
        retryToken?.cancel(); retryToken = nil
        isSyncing = true
        publish()
        performSync { [weak self] outcome in
            guard let self = self else { return }
            self.isSyncing = false
            switch outcome {
            case .success:
                self.lastFailure = nil
                self.lastSyncDate = Date()
                self.backoffIndex = 0
                self.publish()
                if self.pendingCount() > 0 { self.scheduleRetry() } // more arrived mid-sync
            case .offline:
                self.lastFailure = .offline
                self.publish()
                self.scheduleRetry()
            case .failed:
                self.lastFailure = .failed
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
