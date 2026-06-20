import Foundation
import CoreData

/// Builds a `LiveTimeEntry` token from an `EntryModel`-shaped managed object.
/// Read via KVC so this is callable both in the app (EntryModel) and in tests
/// (a raw NSManagedObject). `splitId` has no EntryModel equivalent and is unused
/// on the wire (the POST is built from the managed objects by
/// `submitEventGroupEntries:`), so it is left empty.
func liveTimeEntry(from entry: NSManagedObject) -> LiveTimeEntry {
    func s(_ key: String) -> String { entry.value(forKey: key) as? String ?? "" }
    return LiveTimeEntry(bibNumber: s("bibNumber"), splitId: "", subSplitKind: s("bitKey"),
                         enteredTime: s("absoluteTime"), withPacer: s("withPacer"),
                         stoppedHere: s("stoppedHere"), source: s("source"))
}

/// The single sync path shared by auto-sync and the manual Submit button.
/// Mirrors the `SyncService` flow (login → determine primary/alternate server →
/// deterministic 300-batching) but operates on the *paired managed objects* directly:
/// for each batch it calls `postBatch` and marks those objects submitted on success,
/// so partial progress persists across a mid-run failure.
struct LiveTimeSubmitter {
    let login: (@escaping (Result<Void, Error>) -> Void) -> Void
    let postBatch: (_ entries: [NSManagedObject], _ useAlternate: Bool,
                    _ done: @escaping (Result<Void, Error>) -> Void) -> Void
    let markSubmitted: ([NSManagedObject]) -> Void

    func submit(_ pending: [NSManagedObject],
                progress: @escaping (CGFloat) -> Void,
                completion: @escaping (Result<Void, Error>) -> Void) {
        let total = pending.count
        guard total > 0 else { completion(.success(())); return }
        login { [self] loginResult in
            let useAlternate: Bool
            switch loginResult {
            case .success: useAlternate = false
            case .failure: useAlternate = true
            }
            // Use a serial queue so each postBatch call runs as a distinct task.
            // This guarantees any `defer` in the caller's postBatch closure fires
            // before the next batch begins (the next task is enqueued from within
            // the current task's callback, so it runs only after the current task
            // — including its deferred work — has fully exited).
            let queue = DispatchQueue(label: "com.ost-remote.live-time-submitter")
            submitNext(pending, useAlternate: useAlternate, offset: 0,
                       total: total, queue: queue, progress: progress, completion: completion)
        }
    }

    private func submitNext(_ pending: [NSManagedObject],
                             useAlternate: Bool,
                             offset: Int,
                             total: Int,
                             queue: DispatchQueue,
                             progress: @escaping (CGFloat) -> Void,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        guard offset < total else { completion(.success(())); return }
        let end = min(offset + SyncService.batchSize, total)
        let slice = Array(pending[offset ..< end])
        queue.async { [self] in
            postBatch(slice, useAlternate) { [self] result in
                switch result {
                case .success:
                    markSubmitted(slice)
                    let newOffset = end
                    progress(min(1, CGFloat(newOffset) / CGFloat(total)))
                    // Enqueue the next batch on the serial queue. Because we are
                    // already on `queue`, this task is placed AFTER the current
                    // task completes (including any `defer` in postBatch's closure).
                    queue.async { [self] in
                        submitNext(pending, useAlternate: useAlternate, offset: newOffset,
                                   total: total, queue: queue, progress: progress,
                                   completion: completion)
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
