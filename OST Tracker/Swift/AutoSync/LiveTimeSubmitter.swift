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

/// The single sync path shared by auto-sync and the manual Submit button. Drives
/// `SyncService` for login + deterministic 300-batching; for each batch it POSTs
/// the *paired managed objects* (recovered by an offset cursor) via the injected
/// `postBatch`, and marks them submitted on batch success so partial progress
/// persists across a mid-run failure.
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
        let wire = pending.map(liveTimeEntry(from:))
        var offset = 0
        let service = SyncService(login: login) { batch, useAlternate, done in
            let slice = Array(pending[offset ..< offset + batch.count])
            offset += batch.count
            postBatch(slice, useAlternate) { result in
                if case .success = result {
                    markSubmitted(slice)
                    progress(min(1, CGFloat(offset) / CGFloat(total)))
                }
                done(result)
            }
        }
        service.sync(wire, completion: completion)
    }
}
