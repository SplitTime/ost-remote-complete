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

    /// Upper bound on how long a single sync may run before we assume its
    /// completion was dropped and recover. Generous so it never fires on a slow
    /// but legitimate multi-batch submit.
    static let defaultWatchdogSeconds: TimeInterval = 120
    private let watchdogSeconds: TimeInterval

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
    private var watchdogToken: AutoSyncCancellable?
    /// Bumped each time a sync starts so a late or duplicate completion (or a
    /// watchdog that lost the race to the real callback) can be ignored.
    private var syncGeneration = 0
    private var lastPublished: AutoSyncStatus?

    init(enabled: Bool, debounceSeconds: TimeInterval = 3,
         watchdogSeconds: TimeInterval = AutoSyncEngine.defaultWatchdogSeconds,
         scheduler: AutoSyncScheduler,
         pendingCount: @escaping () -> Int,
         performSync: @escaping (@escaping (SyncOutcome) -> Void) -> Void,
         onStatusChange: @escaping (AutoSyncStatus) -> Void) {
        self.enabled = enabled
        self.debounceSeconds = debounceSeconds
        self.watchdogSeconds = watchdogSeconds
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
        // Connectivity most often recovers exactly here, so retry from a clean
        // backoff rather than the long delay accumulated while suspended.
        backoffIndex = 0
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

    /// Re-publish the current status without scheduling a sync. Used when the
    /// on-screen hold changes the eligible pending count but nothing should sync yet.
    func refresh() { publish() }

    // MARK: - Core

    private func attemptSync() {
        guard enabled, active, !isSyncing, pendingCount() > 0 else { publish(); return }
        retryToken?.cancel(); retryToken = nil
        isSyncing = true
        publish()

        syncGeneration += 1
        let generation = syncGeneration
        // Guard against a performSync that never calls back: a dropped network
        // completion would otherwise latch isSyncing forever. If the watchdog
        // fires first we treat the attempt as failed and let the retry loop recover.
        watchdogToken?.cancel()
        watchdogToken = scheduler.schedule(after: watchdogSeconds) { [weak self] in
            self?.finishSync(generation: generation, outcome: .failed)
        }
        performSync { [weak self] outcome in
            self?.finishSync(generation: generation, outcome: outcome)
        }
    }

    /// Apply the result of a sync attempt exactly once. A callback that lost the
    /// race to the watchdog — or arrived after a background/disable reset — carries
    /// a stale generation (or finds isSyncing already false) and is ignored.
    private func finishSync(generation: Int, outcome: SyncOutcome) {
        guard isSyncing, generation == syncGeneration else { return }
        watchdogToken?.cancel(); watchdogToken = nil
        isSyncing = false
        switch outcome {
        case .success:
            lastFailure = nil
            lastSyncDate = Date()
            backoffIndex = 0
            publish()
            if pendingCount() > 0 { scheduleRetry() } // more arrived mid-sync
        case .offline:
            lastFailure = .offline
            publish()
            scheduleRetry()
        case .failed:
            lastFailure = .failed
            publish()
            scheduleRetry()
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
        // Abandon any in-flight sync too. Its late callback carries a stale
        // generation, and the next attempt re-derives pending from Core Data, so
        // dropping the engine-side result here is safe and keeps isSyncing from
        // latching across a background/disable teardown.
        watchdogToken?.cancel(); watchdogToken = nil
        if isSyncing {
            isSyncing = false
            syncGeneration += 1
        }
    }

    private func publish() {
        let s = currentStatus
        // Once we've resolved to synced there's nothing outstanding we failed on;
        // drop the stale failure so a later new entry rests at .pending, not .failed.
        if s.state == .synced { lastFailure = nil }
        guard s != lastPublished else { return }
        lastPublished = s
        onStatusChange(s)
    }
}
