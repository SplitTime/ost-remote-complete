//
//  AutoSyncController.swift
//  OST Tracker
//
//  Production wiring for the Auto Sync feature. Owns the pure `AutoSyncEngine`
//  and bridges it to Core Data (pending fetch + submitted-flag save), the network
//  (`OSTNetworkManager` via `LiveTimeSubmitter`), app lifecycle, and the legacy
//  delegate/observer callbacks the Review pane and badges rely on. The engine's
//  `Offline` state is derived from the actual submit error (no reachability probe).
//
//  Threading: both network paths deliver their completions on the main queue —
//  `autoLogin` resolves through `OSTAuthBridge.login` (DispatchQueue.main.async)
//  and `submitEventGroupEntries` resolves through `OSTBackend.postJSON`
//  (DispatchQueue.main.async). The Core Data save in `markSubmitted` and every
//  observer/UI callback are therefore guaranteed to run on the main thread; we
//  funnel them through `onMain` to make that invariant explicit and robust.
//

import Foundation
import CoreData
import UIKit

@objc(AutoSyncController)
final class AutoSyncController: NSObject {
    @objc static let shared = AutoSyncController()
    @objc static let statusChangedNotification = Notification.Name("OSTSyncStatusChanged")

    private static let enabledKey = "OSTAutoSyncEnabled"

    private var engine: AutoSyncEngine!
    private let observers = NSHashTable<AnyObject>.weakObjects()
    private var inFlightEntries: [NSManagedObject] = []
    private var usedAlternateServer = false

    @objc var showToastOnCompletion = true
    @objc private(set) var isSyncing = false

    private override init() {
        super.init()
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        engine = AutoSyncEngine(
            enabled: enabled, debounceSeconds: 3, scheduler: TimerScheduler(),
            pendingCount: { [weak self] in self?.fetchPending().count ?? 0 },
            performSync: { [weak self] completion in self?.performAutoSync(completion) },
            onStatusChange: { [weak self] status in self?.broadcast(status) })

        NotificationCenter.default.addObserver(
            self, selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave, object: nil)
    }

    // MARK: - Main-thread funnel

    private func onMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
    }

    // MARK: - Toggle

    @objc var autoSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            engine.setEnabled(newValue)
        }
    }

    // MARK: - Status

    var currentStatus: AutoSyncStatus { engine.currentStatus }
    @objc var currentStatusState: String { engine.currentStatus.state.rawValue }
    @objc var currentPendingCount: Int { engine.currentStatus.pendingCount }

    private func broadcast(_ status: AutoSyncStatus) {
        NotificationCenter.default.post(name: Self.statusChangedNotification, object: self)
    }

    // MARK: - Triggers

    @objc private func contextDidSave(_ note: Notification) {
        // Ignore the controller's own submitted-flag save to avoid a re-trigger loop.
        guard !isSyncing else { return }
        engine.noteEntriesChanged()
    }

    @objc func applicationDidBecomeActive() { engine.enterForeground() }
    @objc func applicationDidEnterBackground() { engine.enterBackground() }
    @objc func forceRetry() { engine.forceRetry() }

    // MARK: - Observers (parity with the old delegate list)

    @objc func addObserver(_ o: AutoSyncObserver) { observers.add(o) }
    @objc func removeObserver(_ o: AutoSyncObserver) { observers.remove(o) }
    private func eachObserver(_ body: (AutoSyncObserver) -> Void) {
        observers.allObjects.compactMap { $0 as? AutoSyncObserver }.forEach(body)
    }

    // MARK: - Manual path (Review pane)

    @objc var syncingEntries: [Any] { inFlightEntries }

    @objc func isSyncingEntry(_ entry: NSObject) -> Bool {
        let id = entry.value(forKey: "entryId") as? NSNumber
        return inFlightEntries.contains { ($0.value(forKey: "entryId") as? NSNumber) == id }
    }

    @objc func syncEntries(_ records: [Any]) {
        let objs = records.compactMap { $0 as? NSManagedObject }
        runSync(objs, completion: nil)
    }

    @objc func syncNow() { runSync(fetchPending(), completion: nil) }

    // MARK: - Sync execution

    private func fetchPending() -> [NSManagedObject] {
        guard let eventId = CurrentCourse.getCurrentCourse()?.eventId else { return [] }
        let req = NSFetchRequest<NSManagedObject>(entityName: "EntryModel")
        req.predicate = NSPredicate(format: "combinedCourseId == %@ && submitted == NIL && bibNumber != %@", eventId, "-1")
        let ctx = NSManagedObjectContext.mr_default()
        return (try? ctx.fetch(req)) ?? []
    }

    /// Used by the engine's auto path: gather + sync, classifying the submit
    /// `Result` into the engine's `SyncOutcome`. A "not connected to internet"
    /// URL error (-1009) maps to `.offline` (the same test the legacy Review pane
    /// used for "device is not connected"); any other failure maps to `.failed`.
    private func performAutoSync(_ completion: @escaping (SyncOutcome) -> Void) {
        runSync(fetchPending()) { result in
            switch result {
            case .success:
                completion(.success)
            case .failure(let error):
                let ns = error as NSError
                let offline = ns.domain == NSURLErrorDomain && ns.code == NSURLErrorNotConnectedToInternet
                completion(offline ? .offline : .failed)
            }
        }
    }

    private func runSync(_ pending: [NSManagedObject], completion: ((Result<Void, Error>) -> Void)?) {
        // Never fire a live network/Core Data submit inside the unit-test host.
        // The singleton's NSManagedObjectContextDidSave observer would otherwise
        // react to other tests' saves and submit test-store EntryModels (faults
        // on `bibNumber` / hits the network). The engine state machine is exercised
        // directly in AutoSyncEngineTests with an injected `performSync` seam.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            completion?(.success(())); return
        }
        guard !isSyncing, !pending.isEmpty else { completion?(.success(())); return }
        isSyncing = true
        inFlightEntries = pending
        usedAlternateServer = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        eachObserver { $0.syncManagerDidStartSynchronization(self) }

        let submitter = LiveTimeSubmitter(
            login: { done in
                AppDelegate.getInstance()?.getNetworkManager().autoLogin(
                    completionBlock: { _ in done(.success(())) },
                    errorBlock: { _ in done(.failure(URLError(.userAuthenticationRequired))) })
            },
            postBatch: { [weak self] entries, useAlternate, done in
                self?.usedAlternateServer = useAlternate
                AppDelegate.getInstance()?.getNetworkManager().submitEventGroupEntries(
                    entries, useAlternateServer: useAlternate,
                    completionBlock: { _ in done(.success(())) },
                    errorBlock: { err in done(.failure(err ?? URLError(.unknown))) })
            },
            markSubmitted: { batch in
                batch.forEach { $0.setValue(NSNumber(value: true), forKey: "submitted") }
                let ctx = NSManagedObjectContext.mr_default()
                ctx.processPendingChanges()
                ctx.mr_saveOnlySelfAndWait()
            })

        submitter.submit(pending, progress: { [weak self] p in
            guard let self = self else { return }
            self.onMain { self.eachObserver { $0.syncManager(self, progress: p) } }
        }) { [weak self] result in
            guard let self = self else { return }
            self.onMain {
                self.isSyncing = false
                self.inFlightEntries = []
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                switch result {
                case .success:
                    self.eachObserver { $0.syncManagerDidFinishSynchronization(self) }
                    self.showToastIfNeeded(errors: [])
                case .failure(let error):
                    let errs = [error as NSError]
                    self.eachObserver { $0.syncManager(self, didFinishSynchronizationWithErrors: errs, alternateServer: self.usedAlternateServer) }
                    self.showToastIfNeeded(errors: errs)
                }
                completion?(result)
            }
        }
    }

    private func showToastIfNeeded(errors: [NSError]) {
        guard showToastOnCompletion else { return }
        OSTToast.show(success: errors.isEmpty)
    }
}
