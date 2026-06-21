import Foundation

/// Reproduces the legacy submit flow (iOS 12, completion handlers):
///  1. Attempt auto-login.
///  2. If login SUCCEEDS, submit to the primary server; if login FAILS, submit
///     to the alternate server. (The alternate is selected by login outcome —
///     not by a submit failure — matching the legacy behavior exactly.)
///  3. Submit in batches of up to 300, in order, recursively.
///
/// `login` and `submitBatch` are injected so the logic is unit-testable without
/// the network. Generic over the batched element so callers can batch whatever
/// they actually submit (e.g. the managed objects themselves), keeping each
/// batch's identity intact instead of recovering it by a parallel index.
final class SyncService<Element> {
    static var batchSize: Int { 300 }

    private let login: (@escaping (Result<Void, Error>) -> Void) -> Void
    private let submitBatch: (_ batch: [Element], _ useAlternate: Bool,
                              _ completion: @escaping (Result<Void, Error>) -> Void) -> Void

    init(login: @escaping (@escaping (Result<Void, Error>) -> Void) -> Void,
         submitBatch: @escaping (_ batch: [Element], _ useAlternate: Bool,
                                 _ completion: @escaping (Result<Void, Error>) -> Void) -> Void) {
        self.login = login
        self.submitBatch = submitBatch
    }

    func sync(_ entries: [Element], completion: @escaping (Result<Void, Error>) -> Void) {
        login { [weak self] result in
            guard let self = self else { return }
            let useAlternate: Bool
            switch result {
            case .success: useAlternate = false
            case .failure: useAlternate = true
            }
            self.submitAll(entries, useAlternate: useAlternate, completion: completion)
        }
    }

    private func submitAll(_ entries: [Element],
                           useAlternate: Bool,
                           completion: @escaping (Result<Void, Error>) -> Void) {
        guard !entries.isEmpty else { completion(.success(())); return }
        let batch = Array(entries.prefix(Self.batchSize))
        submitBatch(batch, useAlternate) { [weak self] result in
            switch result {
            case .success:
                self?.submitAll(Array(entries.dropFirst(batch.count)),
                                useAlternate: useAlternate, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
