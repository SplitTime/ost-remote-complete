import Foundation

/// Reproduces `OSTSyncManager`'s submit flow:
///  1. Attempt auto-login.
///  2. If login SUCCEEDS, submit to the primary server; if login FAILS, submit
///     to the alternate server. (The alternate is selected by login outcome —
///     not by a submit failure — matching the legacy behavior exactly.)
///  3. Submit in batches of up to 300, in order.
///
/// `login` and `submitBatch` are injected so the logic is unit-testable without
/// the network.
final class SyncService {
    static let batchSize = 300

    private let login: () async throws -> Void
    private let submitBatch: (_ batch: [LiveTimeEntry], _ useAlternate: Bool) async throws -> Void

    init(login: @escaping () async throws -> Void,
         submitBatch: @escaping (_ batch: [LiveTimeEntry], _ useAlternate: Bool) async throws -> Void) {
        self.login = login
        self.submitBatch = submitBatch
    }

    func sync(_ entries: [LiveTimeEntry]) async throws {
        let useAlternate: Bool
        do {
            try await login()
            useAlternate = false
        } catch {
            useAlternate = true
        }
        try await submitAll(entries, useAlternate: useAlternate)
    }

    private func submitAll(_ entries: [LiveTimeEntry], useAlternate: Bool) async throws {
        var remaining = entries
        while !remaining.isEmpty {
            let batch = Array(remaining.prefix(Self.batchSize))
            try await submitBatch(batch, useAlternate)
            remaining.removeFirst(batch.count)
        }
    }
}
