// OST Tracker/Swift/AutoSync/AutoSyncScheduler.swift
import Foundation

protocol AutoSyncCancellable { func cancel() }

protocol AutoSyncScheduler {
    @discardableResult
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> AutoSyncCancellable
}

/// Production scheduler backed by a one-shot main-run-loop Timer.
final class TimerScheduler: AutoSyncScheduler {
    private final class TimerToken: AutoSyncCancellable {
        let timer: Timer
        init(_ t: Timer) { timer = t }
        func cancel() { timer.invalidate() }
    }
    @discardableResult
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> AutoSyncCancellable {
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in work() }
        return TimerToken(t)
    }
}
