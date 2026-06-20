//
//  OSTEventSelectionViewController.swift
//  OST Tracker
//
//  Programmatic, themed replacement for the XIB-backed event selection screen.
//  Uses SelectableOptionList and BottomSheetPicker from the design system; no XIB,
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
    var aidStationOptions: [String] = []

    // MARK: - Programmatic views
    private let titleLabel: UILabel = {
        let l = UILabel(); l.text = "Select Event & Aid Station"
        l.font = Theme.Font.title; l.textColor = Theme.label
        l.numberOfLines = 0; return l
    }()
    private let hintLabel: UILabel = {
        let l = UILabel(); l.text = "Choose your event, then your aid station."
        l.font = Theme.Font.field; l.textColor = Theme.secondaryLabel
        l.numberOfLines = 0; return l
    }()
    private let eventList = SelectableOptionList(label: "Event")
    private let aidStationField = AidStationField()
    private let eventStationDivider: UIView = {
        let v = UIView(); v.backgroundColor = Theme.separator
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }()
    private let nextButton = PrimaryButton(title: "Start Tracking", role: .success)
    private let logoutButton: UIButton = {
        let b = UIButton(type: .system); b.setTitle("Log Out", for: .normal)
        b.setTitleColor(Theme.destructive, for: .normal); return b
    }()
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system); b.setTitle("Cancel", for: .normal)
        b.setTitleColor(Theme.tint, for: .normal); return b
    }()
    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .gray); s.hidesWhenStopped = true; return s
    }()
    private let loadingLabel: UILabel = {
        let l = UILabel(); l.text = "Loading events…"; l.textColor = Theme.secondaryLabel
        l.font = Theme.Font.field; l.textAlignment = .center; l.isHidden = true; return l
    }()
    // Kept from before for the post-selection download state:
    private let progressLabel: UILabel = {
        let l = UILabel(); l.textAlignment = .center; l.textColor = Theme.secondaryLabel
        l.font = Theme.Font.field; l.isHidden = true; return l
    }()
    private let progressBar: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default); p.isHidden = true; return p
    }()

    @objc class func loadEventDataAndPresent(from presenter: UIViewController,
                                             completion: ((Error?) -> Void)? = nil) {
        let eventVC = OSTEventSelectionViewController(nibName: nil, bundle: nil)
        eventVC.tempContext = NSManagedObjectContext.mr_context(withParent: NSManagedObjectContext.mr_default())
        eventVC.modalPresentationStyle = .fullScreen
        // Present immediately in the loading state; the VC fetches events itself.
        presenter.present(eventVC, animated: true) { completion?(nil) }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        nextButton.alpha = 0
        setAidStationHidden(true)
        aidStationField.isEnabled = false
        nextButton.addTarget(self, action: #selector(onNext(_:)), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(onLogout(_:)), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(onCancel(_:)), for: .touchUpInside)
        aidStationField.addTarget(self, action: #selector(openAidStationPicker), for: .touchUpInside)

        eventList.onSelect = { [weak self] _ in self?.onEventSelected() }

        let footer = changeStation ? cancelButton : logoutButton
        let loadingRow = UIStackView(arrangedSubviews: [loadingSpinner, loadingLabel])
        loadingRow.axis = .vertical; loadingRow.spacing = 10; loadingRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, hintLabel, eventList, eventStationDivider, aidStationField,
                                                   nextButton, loadingRow, progressLabel, progressBar, footer])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(4, after: titleLabel)
        stack.setCustomSpacing(22, after: hintLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Theme.Metric.horizontalInset),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Theme.Metric.horizontalInset),
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if eventsLoaded { return }

        if changeStation {
            let course = CurrentCourse.getCurrentCourse()
            eventList.options = [course?.eventName ?? ""]
            eventList.select(course?.eventName ?? "")
            let stations = course?.dataEntryGroups as? [[String: Any]] ?? []
            aidStationOptions = stations.compactMap { $0["title"] as? String }
            setAidStationHidden(false)
            aidStationField.isEnabled = true
            unpairedDataEntryGroups = course?.dataEntryGroups as? [Any]
            eventList.isUserInteractionEnabled = false
            eventsLoaded = true
            return
        }

        eventsLoaded = true
        loadEvents()
    }

    // MARK: - Event loading

    /// Fetch the live events list and populate the open selector. Shows the loading
    /// state while in flight; handles error / no-events by alerting on this screen.
    private func loadEvents() {
        loadingSpinner.startAnimating()
        loadingLabel.isHidden = false
        OSTBackend.shared.getAllEvents { [weak self] object, error in
            guard let self = self else { return }
            self.loadingSpinner.stopAnimating()
            self.loadingLabel.isHidden = true

            if error != nil {
                let alert = UIAlertController(title: "Error", message: "Couldn't get the events", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in self.loadEvents() })
                alert.addAction(UIAlertAction(title: "Back to Login", style: .cancel) { _ in self.dismissToLogin() })
                self.present(alert, animated: true)
                return
            }

            let data = (object as? [String: Any])?["data"] as? [Any]
            if (data?.count ?? 0) == 0 {
                AppDelegate.getInstance()?.getNetworkManager()?.addToken(toHeader: nil)
                let alert = UIAlertController(title: "No Events Available",
                    message: "You are not authorized for any live events. Make sure your event is enabled for live entry and that you are authorized as a steward.",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismissToLogin() })
                self.present(alert, animated: true)
                return
            }

            let pickerEvents = NSMutableArray()
            for dataObject in data ?? [] {
                if let event = EventModel.mr_import(from: dataObject, in: self.tempContext) as? EventModel {
                    pickerEvents.add(event)
                }
            }
            pickerEvents.sort(using: [NSSortDescriptor(key: "startTime", ascending: false)])
            self.events = pickerEvents
            let strings = NSMutableArray()
            for case let event as EventModel in pickerEvents { if let name = event.name { strings.add(name) } }
            self.eventStrings = strings

            UserDefaults.standard.set(2, forKey: "reviewScreenPicklistValue")
            UserDefaults.standard.synchronize()

            self.eventList.options = (strings as? [String]) ?? []
            if strings.count == 1, let only = (strings as? [String])?.first {
                self.eventList.select(only) // fires onEventSelected
            }
        }
    }

    private func dismissToLogin() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Field selection

    private func onEventSelected() {
        let eventModels = (events as? [EventModel]) ?? []
        guard let found = eventModels.first(where: { $0.name == eventList.selectedOption }) else { return }
        selectedEvent = found
        let groups = found.dataEntryGroups as? [[String: Any]] ?? []
        aidStationOptions = groups.compactMap { $0["title"] as? String }
        aidStationField.value = nil
        setAidStationHidden(false)
        aidStationField.isEnabled = true
        nextButton.alpha = 0
    }

    private func setAidStationHidden(_ hidden: Bool) {
        aidStationField.isHidden = hidden
        eventStationDivider.isHidden = hidden
    }

    @objc private func openAidStationPicker() {
        BottomSheetPicker.present(from: self, title: "Aid Station",
                                 options: aidStationOptions, selected: aidStationField.value) { [weak self] choice in
            guard let self = self else { return }
            self.aidStationField.value = choice
            UIView.animate(withDuration: 0.3) { self.nextButton.alpha = 1 }
        }
    }

    private func showSelectFields() {
        eventList.isHidden = false
        setAidStationHidden(selectedEvent == nil)
        nextButton.isHidden = false
        nextButton.alpha = (selectedEvent == nil || aidStationField.value == nil) ? 0 : 1
        progressLabel.isHidden = true
        progressBar.isHidden = true
    }

    private func showLoadingFields() {
        [eventList, aidStationField, eventStationDivider, nextButton].forEach { $0.isHidden = true }
        progressLabel.isHidden = false
        progressBar.isHidden = false
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

        guard let firstFound = groups.first(where: { ($0["title"] as? String) == aidStationField.value }) else {
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

        progressLabel.text = "Downloading \(eventList.selectedOption ?? "") Data"
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

/// Tappable field row for the aid station: label + current value/placeholder +
/// chevron. Opens the BottomSheetPicker on tap (wired by the VC). Theme-styled.
private final class AidStationField: UIControl {
    private let valueLabel = UILabel()
    private let placeholder = "Choose an aid station"

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.fieldFill
        layer.cornerRadius = Theme.Metric.cornerRadius
        layer.borderWidth = 1
        layer.borderColor = Theme.separator.cgColor

        let caption = UILabel()
        caption.text = "AID STATION"; caption.font = Theme.Font.caption; caption.textColor = Theme.secondaryLabel

        valueLabel.text = placeholder; valueLabel.font = Theme.Font.field; valueLabel.textColor = Theme.secondaryLabel
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)  // stretch → caret sits far right
        let chevron = UILabel(); chevron.text = "▾"; chevron.textColor = Theme.secondaryLabel
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueRow = UIStackView(arrangedSubviews: [valueLabel, chevron])
        valueRow.alignment = .center
        let outer = UIStackView(arrangedSubviews: [caption, valueRow])
        outer.axis = .vertical; outer.spacing = 4
        outer.isUserInteractionEnabled = false
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            outer.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    var value: String? {
        didSet {
            valueLabel.text = value ?? placeholder
            valueLabel.textColor = value == nil ? Theme.secondaryLabel : Theme.label
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            layer.borderColor = Theme.separator.cgColor
        }
    }
}
