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
    private var syncCalls = 0
    private var pendingSyncCompletion: ((SyncOutcome) -> Void)?
    private var statuses: [AutoSyncStatus] = []

    private func makeEngine(enabled: Bool = true) -> AutoSyncEngine {
        sched = ManualScheduler()
        return AutoSyncEngine(
            enabled: enabled, debounceSeconds: 3, scheduler: sched,
            pendingCount: { self.pending },
            performSync: { completion in self.syncCalls += 1; self.pendingSyncCompletion = completion },
            onStatusChange: { self.statuses.append($0) })
    }
    // Drive the engine through the injected `performSync` completion. The
    // production wiring classifies the submit error; here we feed the outcome.
    private func succeed() { pending = 0; pendingSyncCompletion?(.success); pendingSyncCompletion = nil }
    private func offline() { pendingSyncCompletion?(.offline); pendingSyncCompletion = nil }
    private func fail()    { pendingSyncCompletion?(.failed);  pendingSyncCompletion = nil }

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
        succeed()
        XCTAssertEqual(e.currentStatus.state, .synced)
        XCTAssertNotNil(e.currentStatus.lastSyncDate)
    }

    func test_failure_backsOff_5_15_30_60_60() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()              // attempt 1
        fail(); sched.fireAll()                              // retry after 5
        fail(); sched.fireAll()                              // retry after 15
        fail(); sched.fireAll()                              // retry after 30
        fail(); sched.fireAll()                              // retry after 60
        fail()                                               // schedules retry after 60 (cap)
        XCTAssertEqual(observedRetryDelays(e), [5, 15, 30, 60, 60])
        XCTAssertEqual(e.currentStatus.state, .failed)
    }

    func test_success_resetsBackoff() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()
        fail()                                               // schedules retry after 5
        sched.fireAll()                                      // retry attempt
        succeed()                                            // success resets backoff
        pending = 1
        e.noteEntriesChanged(); sched.fireAll()
        fail()                                               // next failure schedules after 5 again
        XCTAssertEqual(lastRetryDelay(e), 5)
    }

    func test_offline_outcome_setsStateAndRetries_andAlwaysReattempts() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()              // attempt 1
        XCTAssertEqual(syncCalls, 1)
        offline()                                            // submit reports offline
        XCTAssertEqual(e.currentStatus.state, .offline)
        XCTAssertEqual(sched.delays, [5], "offline schedules a retry")
        sched.fireAll()                                      // fire the retry
        XCTAssertEqual(syncCalls, 2, "retry always re-attempts the sync now")
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

    func test_reEnable_clearsStaleFailure() {
        pending = 1
        let e = makeEngine()
        e.noteEntriesChanged(); sched.fireAll()
        fail()
        XCTAssertEqual(e.currentStatus.state, .failed)
        e.setEnabled(false)
        e.setEnabled(true)                                   // fresh enable
        XCTAssertNotEqual(e.currentStatus.state, .failed, "re-enable clears stale failure")
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
