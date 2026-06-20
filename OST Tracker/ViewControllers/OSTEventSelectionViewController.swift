//
//  OSTEventSelectionViewController.swift
//  OST Tracker
//
//  Programmatic, themed replacement for the XIB-backed event selection screen.
//  Uses DisclosureSelectField and PrimaryButton from the design system; no XIB,
//  no @IBOutlet/@IBAction, no full-screen background image.
//
//  Two modes:
//   - initial event + aid-station selection (login flow, via the class method
//     `loadEventDataAndPresent(from:completion:)`)
//   - `changeStation` mode (Utilities → Change Station): aid station only.
//

import UIKit
import CoreData

@objc(OSTEventSelectionViewController)
class OSTEventSelectionViewController: UIViewController {

    // MARK: - Public / interop (set from Obj-C re-auth login + Swift Utilities)
    @objc var changeStation = false
    @objc var tempContext: NSManagedObjectContext?
    @objc var events: NSMutableArray?
    @objc var eventStrings: NSMutableArray?

    // MARK: - Internal state
    var selectedEvent: EventModel?
    var unpairedDataEntryGroups: [Any]?
    var eventsLoaded = false

    // MARK: - Programmatic views
    private let eventField = DisclosureSelectField(label: "Event", placeholder: "Choose an event")
    private let stationField = DisclosureSelectField(label: "Aid Station", placeholder: "Select an aid station")
    private let nextButton = PrimaryButton(title: "Start Tracking", role: .success)
    private let logoutButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Log Out", for: .normal)
        b.setTitleColor(Theme.destructive, for: .normal)
        return b
    }()
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.setTitleColor(Theme.tint, for: .normal)
        return b
    }()
    private let progressLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.textColor = Theme.secondaryLabel
        l.font = Theme.Font.field
        l.isHidden = true
        return l
    }()
    private let progressBar: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.isHidden = true
        return p
    }()
    private let activityIndicator: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .gray)
        s.hidesWhenStopped = true
        return s
    }()

    // MARK: - Data loading + presentation

    /// Loads the live events list (network + CoreData import) and presents a fresh
    /// event-selection screen from `presenter`. Owns its own data loading so the
    /// (Swift) login screen just calls this. `completion` is invoked with nil on
    /// success (after presenting) or an error (alerts are shown internally).
    @objc class func loadEventDataAndPresent(from presenter: UIViewController,
                                             completion: ((Error?) -> Void)? = nil) {
        let eventVC = OSTEventSelectionViewController(nibName: nil, bundle: nil)
        eventVC.tempContext = NSManagedObjectContext.mr_context(withParent: NSManagedObjectContext.mr_default())

        OSTBackend.shared.getAllEvents { object, error in
            if let error = error {
                let alert = UIAlertController(title: "Error",
                                             message: "Couldn't get the events",
                                             preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Try Again", style: .cancel) { _ in
                    OSTEventSelectionViewController.loadEventDataAndPresent(from: presenter, completion: completion)
                })
                presenter.present(alert, animated: true)
                completion?(error)
                return
            }

            let data = (object as? [String: Any])?["data"] as? [Any]
            if (data?.count ?? 0) == 0 {
                AppDelegate.getInstance()?.getNetworkManager()?.addToken(toHeader: nil)
                presenter.ostPresentAlert(title: "No Events Available",
                                          message: "You are not authorized for any live events. Make sure your event is enabled for live entry and that you are authorized as a steward.")
                completion?(NSError(domain: "OST", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "No events available"]))
                return
            }

            let pickerEvents = NSMutableArray()
            for dataObject in data ?? [] {
                if let event = EventModel.mr_import(from: dataObject, in: eventVC.tempContext) as? EventModel {
                    pickerEvents.add(event)
                }
            }
            pickerEvents.sort(using: [NSSortDescriptor(key: "startTime", ascending: false)])

            eventVC.events = pickerEvents
            let strings = NSMutableArray()
            for case let event as EventModel in pickerEvents {
                if let name = event.name { strings.add(name) }
            }
            eventVC.eventStrings = strings

            eventVC.modalPresentationStyle = .fullScreen
            presenter.present(eventVC, animated: true, completion: nil)

            UserDefaults.standard.set(2, forKey: "reviewScreenPicklistValue")
            UserDefaults.standard.synchronize()

            completion?(nil)
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        // In changeStation mode "Start Tracking" is intentionally hidden until the user
        // selects a station — a deliberate UX change from the old screen, which showed it immediately.
        nextButton.alpha = 0
        stationField.isHidden = true
        nextButton.addTarget(self, action: #selector(onNext(_:)), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(onLogout(_:)), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(onCancel(_:)), for: .touchUpInside)

        eventField.onSelect = { [weak self] _ in self?.onEventSelected() }
        stationField.onSelect = { [weak self] _ in
            UIView.animate(withDuration: 0.3) { self?.nextButton.alpha = 1 }
        }

        let footer = changeStation ? cancelButton : logoutButton
        let stack = UIStackView(arrangedSubviews: [eventField, stationField, nextButton,
                                                   progressLabel, progressBar, activityIndicator, footer])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Theme.Metric.horizontalInset),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Theme.Metric.horizontalInset),
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
        ])

        if changeStation {
            eventField.isUserInteractionEnabled = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if eventsLoaded { return }

        if changeStation {
            let course = CurrentCourse.getCurrentCourse()
            eventField.options = [course?.eventName ?? ""]
            eventField.select(course?.eventName ?? "")
            let stations = course?.dataEntryGroups as? [[String: Any]] ?? []
            stationField.options = stations.compactMap { $0["title"] as? String }
            stationField.isHidden = false
            unpairedDataEntryGroups = course?.dataEntryGroups as? [Any]
            return
        }

        eventField.options = (eventStrings as? [String]) ?? []
        eventsLoaded = true
        if (eventStrings?.count ?? 0) == 1, let only = (eventStrings as? [String])?.first {
            eventField.select(only)   // triggers onEventSelected via onSelect
        }
    }

    // MARK: - Field selection

    private func onEventSelected() {
        let eventModels = (events as? [EventModel]) ?? []
        guard let found = eventModels.first(where: { $0.name == eventField.selectedOption }) else { return }
        selectedEvent = found
        let groups = found.dataEntryGroups as? [[String: Any]] ?? []
        stationField.reset()
        stationField.options = groups.compactMap { $0["title"] as? String }
        UIView.animate(withDuration: 0.3) { self.stationField.isHidden = false }
    }

    // MARK: - Field visibility

    private func showSelectFields() {
        eventField.isHidden = false
        nextButton.isHidden = false
        stationField.isHidden = (selectedEvent == nil)
        progressLabel.isHidden = true
        progressBar.isHidden = true
        activityIndicator.stopAnimating()
    }

    private func showLoadingFields() {
        [eventField, stationField, nextButton].forEach { $0.isHidden = true }
        progressLabel.isHidden = false
        progressBar.isHidden = false
        activityIndicator.startAnimating()
    }

    // MARK: - Actions

    @objc func onCancel(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        dismiss(animated: true, completion: nil)
    }

    @objc func onLogout(_ sender: Any) {
        ostShowBlockingSpinner()
        AppDelegate.getInstance()?.getNetworkManager()?.autoLogin(completionBlock: { [weak self] _ in
            guard let self = self else { return }
            self.ostHideBlockingSpinner()
            let alert = UIAlertController(title: "Are you sure you would like to log out?",
                                          message: "You will not be able to log back in or add entries until you have a data connection again.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
                AppDelegate.getInstance()?.logout()
            })
            self.present(alert, animated: true)
        }, errorBlock: { [weak self] _ in
            self?.ostHideBlockingSpinner()
            self?.ostPresentAlert(title: "Logout is disabled",
                                  message: "Please try again when you have an Internet connection")
        })
    }

    @objc func onNext(_ sender: Any) {
        let groups: [[String: Any]]
        if let unpaired = unpairedDataEntryGroups {
            groups = unpaired.compactMap { $0 as? [String: Any] }
        } else {
            groups = selectedEvent?.dataEntryGroups as? [[String: Any]] ?? []
        }

        guard let firstFound = groups.first(where: { ($0["title"] as? String) == stationField.selectedOption }) else {
            ostPresentAlert(title: "", message: "You need to select an aid station to continue.")
            return
        }

        let splitIdValue = (firstFound["entries"] as? [[String: Any]])?.first?["splitId"]
        let splitId = (splitIdValue as? NSNumber)?.stringValue ?? splitIdValue as? String
        let title = firstFound["title"] as? String

        if changeStation {
            let currentCourse = CurrentCourse.getCurrentCourse()
            currentCourse?.splitId = splitId
            currentCourse?.splitName = title
            currentCourse?.splitAttributes = firstFound
            NSManagedObjectContext.mr_default().processPendingChanges()
            NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()

            AppDelegate.getInstance()?.showTracker()
            dismiss(animated: true, completion: nil)
            return
        }

        progressLabel.text = "Downloading \(eventField.selectedOption ?? "") Data"
        showLoadingFields()
        progressBar.progress = 0.5

        guard let selectedEvent = selectedEvent else { return }
        OSTBackend.shared.getEventsDetails(selectedEvent.eventId ?? "") { [weak self] object, error in
            guard let self = self else { return }
            if error != nil {
                self.showSelectFields()
                self.ostPresentAlert(title: "Error", message: "Couldn't get course details")
                return
            }
            self.progressBar.progress = 1
            self.activityIndicator.stopAnimating()

            guard let currentCourse = CurrentCourse.mr_createEntity() as? CurrentCourse else { return }

            let root = object as? [String: Any]
            let attributes = (root?["data"] as? [String: Any])?["attributes"] as? [String: Any]
            currentCourse.dataEntryGroups = attributes?["dataEntryGroups"]

            let included = root?["included"] as? [[String: Any]] ?? []
            EffortModel.mr_reconcile(fromIncluded: included, ofType: "efforts")

            currentCourse.eventId = selectedEvent.eventId
            currentCourse.splitId = splitId
            currentCourse.splitName = title
            currentCourse.eventName = selectedEvent.name
            currentCourse.multiLap = selectedEvent.multiLap
            currentCourse.splitAttributes = firstFound
            currentCourse.monitorPacers = attributes?["monitorPacers"] as? NSNumber
            currentCourse.eventGroupId = selectedEvent.eventGroupId

            var eventIdsAndSplits = [String: [Any]]()
            var eventShortNames = [String: String]()
            for dict in included where (dict["type"] as? String) == "events" {
                guard let eid = dict["id"] as? String else { continue }
                let attrs = dict["attributes"] as? [String: Any]
                if let shortName = attrs?["shortName"] as? String {
                    eventShortNames[eid] = shortName
                }
                var arr = eventIdsAndSplits[eid] ?? []
                if let psn = attrs?["parameterizedSplitNames"] { arr.append(psn) }
                eventIdsAndSplits[eid] = arr
            }
            currentCourse.eventIdsAndSplits = eventIdsAndSplits
            currentCourse.eventShortNames = eventShortNames

            NSManagedObjectContext.mr_default().processPendingChanges()
            NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()

            AppDelegate.getInstance()?.loadLeftMenu()
        }
    }
}
