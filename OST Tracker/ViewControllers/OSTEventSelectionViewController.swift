//
//  OSTEventSelectionViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 2). Keeps the existing XIB; the custom class
//  still resolves to "OSTEventSelectionViewController" via @objc. OHAlertView is
//  replaced with native UIAlertController. Still uses the Obj-C network manager,
//  MagicalRecord, IQDropDownTextField/IQKeyboardManager and the Dejal spinner via
//  bridging (those layers are migrated in later phases).
//
//  Two modes:
//   - initial event + aid-station selection (login flow, via the class method
//     `loadEventDataAndPresent(from:completion:)`)
//   - `changeStation` mode (Utilities → Change Station): aid station only.
//

import UIKit
import CoreData
import MFSideMenu
import MagicalRecord
import IQDropDownTextField
import IQKeyboardManager

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
    private var didApplySafeAreaShift = false

    // MARK: - XIB outlets
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var txtEvent: IQDropDownTextField!
    @IBOutlet weak var txtStation: IQDropDownTextField!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var imgTriangleAidStation: UIImageView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var lblSelectEvent: UILabel!
    @IBOutlet weak var lblSelectAidStation: UILabel!
    @IBOutlet weak var btnLogout: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var eventTriangle: UIImageView!
    @IBOutlet weak var progressBar: UIProgressView!

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
        txtEvent.isOptionalDropDown = false

        txtEvent.inputAccessoryView = makeDoneToolbar(action: #selector(onDoneSelectedEvent))
        txtStation.inputAccessoryView = makeDoneToolbar(action: #selector(onDoneSelectedStation))

        btnNext.alpha = 0
        txtStation.alpha = 0

        if changeStation {
            eventTriangle.isHidden = true
            lblSelectEvent.textAlignment = .center
            lblSelectEvent.text = "(Please logout to change events)"
            imgTriangleAidStation.isHidden = false
            txtEvent.textAlignment = .center
            txtEvent.font = UIFont.boldSystemFont(ofSize: 16)
            btnNext.setImage(UIImage(named: "Live Entry"), for: .normal)
        } else {
            btnCancel.isHidden = true
            btnLogout.isHidden = false
            txtEvent.layer.borderColor = UIColor.white.cgColor
            txtEvent.layer.borderWidth = 1
            txtEvent.layer.cornerRadius = 3
        }

        txtStation.layer.borderColor = UIColor.white.cgColor
        txtStation.layer.borderWidth = 1
        txtStation.layer.cornerRadius = 3

        txtStation.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 20))
        txtStation.leftViewMode = .always
        txtEvent.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 20))
        txtEvent.leftViewMode = .always

        progressBar.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)

        IQKeyboardManager.shared().isEnabled = true

        txtStation.removeInputAssistant()
        txtEvent.removeInputAssistant()
    }

    // This XIB predates safe-area layout: content was positioned for a 20pt status
    // bar, so on Dynamic Island devices the logo/Logout bled under the island. One
    // time shift of all content (except the full-screen background) down by the
    // extra top inset. Portrait-only, so applying once is sufficient.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if didApplySafeAreaShift { return }
        let extraTop = view.safeAreaInsets.top - 20.0 // old design assumed a 20pt status bar
        if extraTop <= 0.5 { return } // legacy devices (iPad mini 2/3 etc.): nothing to do
        didApplySafeAreaShift = true
        for sub in view.subviews {
            if sub is UIImageView, sub.frame == view.bounds { continue } // skip full-screen bg
            sub.frame.origin.y += extraTop
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if eventsLoaded { return }

        if changeStation {
            let course = CurrentCourse.getCurrentCourse()
            txtEvent.isUserInteractionEnabled = false
            txtEvent.itemList = [course?.eventName ?? ""]

            let stations = course?.dataEntryGroups as? [[String: Any]] ?? []
            txtStation.itemList = stations.compactMap { $0["title"] as? String }
            txtStation.becomeFirstResponder()

            btnNext.alpha = 1
            txtStation.alpha = 1
            unpairedDataEntryGroups = course?.dataEntryGroups as? [Any]
            return
        }

        txtEvent.itemList = (eventStrings as? [String]) ?? []
        txtEvent.becomeFirstResponder()
        eventsLoaded = true

        if (eventStrings?.count ?? 0) == 1 {
            onDoneSelectedEvent()
        }
    }

    // MARK: - Dropdown selection

    @objc func onDoneSelectedEvent() {
        txtEvent.resignFirstResponder()

        let eventModels = (events as? [EventModel]) ?? []
        guard let firstFound = eventModels.first(where: { $0.name == txtEvent.selectedItem }) else {
            return
        }
        selectedEvent = firstFound

        let groups = firstFound.dataEntryGroups as? [[String: Any]] ?? []
        txtStation.itemList = groups.compactMap { $0["title"] as? String }

        UIView.animate(withDuration: 0.3) {
            self.txtStation.alpha = 1
            self.imgTriangleAidStation.isHidden = false
        }
        txtStation.becomeFirstResponder()
    }

    @objc func onDoneSelectedStation() {
        txtStation.resignFirstResponder()
        UIView.animate(withDuration: 0.8) { self.btnNext.alpha = 1 }
    }

    // MARK: - Field visibility

    private func showSelectFields() {
        lblSelectEvent.isHidden = false
        lblSelectAidStation.isHidden = false
        btnNext.isHidden = false
        txtEvent.isHidden = false
        txtStation.isHidden = false
        eventTriangle.isHidden = false
        imgTriangleAidStation.isHidden = false

        progressLabel.isHidden = true
        activityIndicator.stopAnimating()
        progressBar.isHidden = true
    }

    private func showLoadingFields() {
        lblSelectEvent.isHidden = true
        lblSelectAidStation.isHidden = true
        btnNext.isHidden = true
        txtEvent.isHidden = true
        txtStation.isHidden = true
        eventTriangle.isHidden = true
        imgTriangleAidStation.isHidden = true

        progressLabel.isHidden = false
        activityIndicator.startAnimating()
        progressBar.isHidden = false
    }

    // MARK: - Actions

    @IBAction func onCancel(_ sender: Any) {
        IQKeyboardManager.shared().isEnabled = false
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onLogout(_ sender: Any) {
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

    @IBAction func onNext(_ sender: Any) {
        let groups: [[String: Any]]
        if let unpaired = unpairedDataEntryGroups {
            groups = unpaired.compactMap { $0 as? [String: Any] }
        } else {
            groups = selectedEvent?.dataEntryGroups as? [[String: Any]] ?? []
        }

        guard let firstFound = groups.first(where: { ($0["title"] as? String) == txtStation.selectedItem }) else {
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

            IQKeyboardManager.shared().isEnabled = false

            AppDelegate.getInstance()?.showTracker()
            dismiss(animated: true, completion: nil)
            return
        }

        progressLabel.text = "Downloading \(txtEvent.selectedItem ?? "") Data"
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
            for dataObject in included where (dataObject["type"] as? String) == "efforts" {
                EffortModel.mr_import(from: dataObject)
            }

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

    // MARK: - Helpers

    private func makeDoneToolbar(action: Selector) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: action)
        toolbar.items = [flex, done]
        return toolbar
    }
}
