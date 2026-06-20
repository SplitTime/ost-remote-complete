// OST TrackerTests/Swift/AutoSyncEngineTests.swift
import XCTest
@testable import OST_Remote

private final class ManualScheduler: AutoSyncScheduler {
    final class Token: AutoSyncCancellable {
        var cancelled = false
        func cancel() { cancelled = true }
    }
    struct Scheduled { let delay: TimeInterval; let work: () -> Void; let token: Token }
    private(set) var scheduled: [Scheduled] = []
    var delays: [TimeInterval] { scheduled.filter { !$0.token.cancelled }.map { $0.delay } }
    var allRetryDelays: [TimeInterval] = []

    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> AutoSyncCancellable {
        if seconds != 3 { allRetryDelays.append(seconds) }
        let t = Token(); scheduled.append(Scheduled(delay: seconds, work: work, token: t)); return t
    }
    /// Fire all currently-pending (non-cancelled) blocks once, in order.
    func fireAll() {
        let live = scheduled.filter { !$0.token.cancelled }
        scheduled.removeAll()
        live.forEach { $0.work() }
    }
}

final class AutoSyncEngineTests: XCTestCase {
    private var sched: ManualScheduler!
    private var pending = 0
    private var reachable = true
    private var syncCalls = 0
    private var pendingSyncCompletion: ((Result<Void, Error>) -> Void)?
    private var statuses: [AutoSyncStatus] = []

    private func makeEngine(enabled: Bool = true) -> AutoSyncEngine {
        sched = ManualScheduler()
        return AutoSyncEngine(
            enabled: enabled, debounceSeconds: 3, scheduler: sched,
            pendingCount: { self.pending },
            isReachable: { self.reachable },
            performSync: { completion in self.syncCalls += 1; self.pendingSyncCompletion = completion },
            onStatusChange: { self.statuses.append($0) })
    }
    private func succeedSync() { pending = 0; pendingSyncCompletion?(.success(())); pendingSyncCompletion = nil }
    private func failSync() { pendingSyncCompletion?(.failure(URLError(.badServerResponse))); pendingSyncCompletion = nil }

    func test_enableWithPending_triggersSync() {
        pending = 2
        let e = makeEngine(enabled: false)
        e.setEnabled(true)
        XCTAssertEqual(syncCalls, 1)
        XCTAssertEqual(e.currentStatus.state, .syncing)
    }

    func test_debounce_coalescesRapidEntries() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); e.noteEntriesChanged(); e.noteEntriesChanged()
        XCTAssertEqual(syncCalls, 0, "debounce not yet fired")
        sched.fireAll()
        XCTAssertEqual(syncCalls, 1, "three rapid changes coalesce into one sync")
    }

    func test_happyPath_pendingSyncingSynced() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged()
        XCTAssertEqual(e.currentStatus.state, .pending)
        sched.fireAll()
        XCTAssertEqual(e.currentStatus.state, .syncing)
        succeedSync()
        XCTAssertEqual(e.currentStatus.state, .synced)
        XCTAssertNotNil(e.currentStatus.lastSyncDate)
    }

    func test_failure_backsOff_5_15_30_60_60() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()              // attempt 1
        failSync(); sched.fireAll()                          // retry after 5
        failSync(); sched.fireAll()                          // retry after 15
        failSync(); sched.fireAll()                          // retry after 30
        failSync(); sched.fireAll()                          // retry after 60
        failSync()                                           // schedules retry after 60 (cap)
        // The scheduled retry delays observed, in order:
        XCTAssertEqual(observedRetryDelays(e), [5, 15, 30, 60, 60])
    }

    func test_success_resetsBackoff() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()
        failSync()                                           // schedules retry after 5
        sched.fireAll()                                      // retry attempt
        succeedSync()                                        // success resets backoff
        pending = 1
        e.noteEntriesChanged(); sched.fireAll()
        failSync()                                           // next failure schedules after 5 again
        XCTAssertEqual(lastRetryDelay(e), 5)
    }

    func test_offline_whenUnreachable_doesNotCallSync() {
        pending = 1; reachable = false
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()
        XCTAssertEqual(syncCalls, 0)
        XCTAssertEqual(e.currentStatus.state, .offline)
        reachable = true
        e.reachabilityChanged()
        XCTAssertEqual(syncCalls, 1)
    }

    func test_inFlightGuard_noOverlap() {
        pending = 2
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()
        XCTAssertEqual(syncCalls, 1)
        e.noteEntriesChanged(); sched.fireAll()              // while first still in flight
        XCTAssertEqual(syncCalls, 1, "no second concurrent sync")
    }

    func test_disable_stopsTimersAndHides() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged()
        e.setEnabled(false)
        sched.fireAll()
        XCTAssertEqual(syncCalls, 0)
        XCTAssertEqual(e.currentStatus.state, .disabled)
    }

    func test_background_pauses_foreground_resumes() {
        pending = 1
        let e = makeEngine()
        e.enterBackground()
        e.noteEntriesChanged(); sched.fireAll()
        XCTAssertEqual(syncCalls, 0, "no sync while backgrounded")
        e.enterForeground()
        XCTAssertEqual(syncCalls, 1, "foreground resumes and syncs pending")
    }

    // Helpers: the retry timer is the only multi-second schedule the engine makes
    // after a failure (debounce is always 3s); read its delay from the scheduler.
    private func observedRetryDelays(_ e: AutoSyncEngine) -> [TimeInterval] { retryDelaysLog }
    private func lastRetryDelay(_ e: AutoSyncEngine) -> TimeInterval { retryDelaysLog.last ?? -1 }
    private var retryDelaysLog: [TimeInterval] { sched.allRetryDelays }
}
