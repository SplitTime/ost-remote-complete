// OST Tracker/ViewControllers/OSTRightMenuViewController.swift
import UIKit
import CoreData

/// Right-side navigation drawer on the design system. Two themed cards — a
/// NAVIGATION section (screens) and a SETTINGS section (former Utilities actions)
/// — plus the Auto Sync toggle and a destructive Log Out button, all inside a
/// scroll view so the list never clips. Subclasses the Obj-C `OSTBaseViewController`
/// for the unsynced-count badge + AutoSync observer. Hosted by `OSTDrawerContainer`.
@objc(OSTRightMenuViewController)
final class OSTRightMenuViewController: OSTBaseViewController {

    // Navigation
    private let liveEntryRow  = MenuRow(title: "Live Entry")
    private let reviewSyncRow = MenuRow(title: "Review / Sync")
    private let crossCheckRow = MenuRow(title: "Cross Check")
    private let liveReadsRow  = MenuRow(title: "Live Reads")
    private let raceOverviewRow = MenuRow(title: "Race Overview")

    // Settings (formerly the Utilities screen)
    private let refreshRosterRow = MenuRow(title: "Refresh Roster")
    private let changeStationRow = MenuRow(title: "Change Station")
    private let appearanceRow    = MenuRow(title: "Appearance")
    private let aboutRow         = MenuRow(title: "About")

    private let autoSyncSwitch = UISwitch()
    private let logoutButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Log Out", for: .normal)
        b.setTitleColor(Theme.destructive, for: .normal)
        b.titleLabel?.font = Theme.Font.button
        return b
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reviewSyncRow.showsSpinner = AutoSyncController.shared.isSyncing
        autoSyncSwitch.isOn = AutoSyncController.shared.autoSyncEnabled
        appearanceRow.detailText = AppearanceController.shared.mode.displayName
        updateSyncBadge()
    }

    // MARK: - UI

    private func buildUI() {
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close \u{2715}", for: .normal)
        closeButton.setTitleColor(Theme.tint, for: .normal)
        closeButton.titleLabel?.font = Theme.Font.button
        closeButton.addTarget(self, action: #selector(onClose), for: .touchUpInside)
        let closeRow = UIStackView(arrangedSubviews: [UIView(), closeButton])
        closeRow.alignment = .center

        let logo = UIImageView(image: UIImage(named: "OST Logo"))
        logo.contentMode = .scaleAspectFit
        logo.widthAnchor.constraint(equalToConstant: 34).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let brandLabel = UILabel()
        brandLabel.text = "OST Remote"
        brandLabel.font = Theme.Font.brand
        brandLabel.textColor = Theme.label
        let brandRow = UIStackView(arrangedSubviews: [logo, brandLabel, UIView()])
        brandRow.alignment = .center
        brandRow.spacing = 10

        liveEntryRow.addTarget(self, action: #selector(onLiveEntry), for: .touchUpInside)
        reviewSyncRow.addTarget(self, action: #selector(onReviewSync), for: .touchUpInside)
        crossCheckRow.addTarget(self, action: #selector(onCrossCheck), for: .touchUpInside)
        liveReadsRow.addTarget(self, action: #selector(onLiveReads), for: .touchUpInside)
        raceOverviewRow.addTarget(self, action: #selector(onRaceOverview), for: .touchUpInside)
        let navCard = makeCard(rows: [liveEntryRow, reviewSyncRow, crossCheckRow, liveReadsRow, raceOverviewRow])

        refreshRosterRow.showsChevron = false
        refreshRosterRow.addTarget(self, action: #selector(onRefreshRoster), for: .touchUpInside)
        changeStationRow.addTarget(self, action: #selector(onChangeStation), for: .touchUpInside)
        appearanceRow.detailText = AppearanceController.shared.mode.displayName
        appearanceRow.addTarget(self, action: #selector(onAppearance), for: .touchUpInside)
        aboutRow.addTarget(self, action: #selector(onAbout), for: .touchUpInside)
        let settingsCard = makeCard(rows: [refreshRosterRow, changeStationRow, appearanceRow, aboutRow])

        let autoLabel = UILabel()
        autoLabel.text = "Auto Sync"
        autoLabel.font = Theme.Font.field
        autoLabel.textColor = Theme.label
        autoSyncSwitch.isOn = AutoSyncController.shared.autoSyncEnabled
        autoSyncSwitch.addTarget(self, action: #selector(onAutoSyncSwitch(_:)), for: .valueChanged)
        let autoRow = UIStackView(arrangedSubviews: [autoLabel, UIView(), autoSyncSwitch])
        autoRow.alignment = .center
        autoRow.isLayoutMarginsRelativeArrangement = true
        autoRow.layoutMargins = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        logoutButton.addTarget(self, action: #selector(onLogout), for: .touchUpInside)

        let content = UIStackView(arrangedSubviews: [
            closeRow, brandRow,
            makeSectionHeader("NAVIGATION"), navCard,
            makeSectionHeader("SETTINGS"), settingsCard,
            autoRow,
            logoutButton,
        ])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(20, after: brandRow)
        content.setCustomSpacing(20, after: navCard)
        content.setCustomSpacing(16, after: settingsCard)
        content.setCustomSpacing(24, after: autoRow)
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        scroll.addSubview(content)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: guide.trailingAnchor),

            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    private func makeCard(rows: [MenuRow]) -> UIView {
        let listStack = UIStackView()
        listStack.axis = .vertical
        for (i, row) in rows.enumerated() {
            listStack.addArrangedSubview(row)
            if i < rows.count - 1 { listStack.addArrangedSubview(makeSeparator()) }
        }
        let card = UIView()
        card.backgroundColor = Theme.fieldFill
        card.layer.cornerRadius = Theme.Metric.cornerRadius
        card.clipsToBounds = true
        listStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(listStack)
        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: card.topAnchor),
            listStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            listStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])
        return card
    }

    private func makeSectionHeader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = Theme.Font.caption
        l.textColor = Theme.secondaryLabel
        return l
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.separator
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: - Navigation actions

    @objc private func onClose() {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        if let tracker = AppDelegate.getInstance()?.rightMenuVC.centerViewController as? OSTRunnerTrackerViewController {
            tracker.txtBibNumber.becomeFirstResponder()
        }
    }

    // Picking a destination always *closes* the drawer — never toggle here, or a
    // destination that closes the drawer itself (see OSTRunnerTrackerViewController)
    // would flip `isOpen` first and turn this toggle into a re-open.

    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
    }

    @objc private func onReviewSync() {
        AppDelegate.getInstance()?.showReview()
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
    }

    @objc private func onCrossCheck() {
        let storyboard = UIStoryboard(name: "CrossCheck", bundle: nil)
        if let controller = storyboard.instantiateInitialViewController() {
            AppDelegate.getInstance()?.rightMenuVC.centerViewController = controller
            AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
        }
    }

    @objc private func onLiveReads() {
        AppDelegate.getInstance()?.rightMenuVC.centerViewController = OSTLiveReadsViewController()
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
    }

    @objc private func onRaceOverview() {
        AppDelegate.getInstance()?.rightMenuVC.centerViewController = OSTRaceOverviewViewController()
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
    }

    @objc private func onAutoSyncSwitch(_ sender: UISwitch) {
        AutoSyncController.shared.autoSyncEnabled = sender.isOn
    }

    // MARK: - Settings actions (ported from OSTUtilitiesViewController)

    @objc private func onRefreshRoster() {
        guard let currentCourse = CurrentCourse.getCurrentCourse() else { return }
        refreshRosterRow.showsSpinner = true
        refreshRosterRow.isEnabled = false

        OSTBackend.shared.getEventsDetails(currentCourse.eventId ?? "") { [weak self] object, error in
            guard let self = self else { return }
            self.refreshRosterRow.showsSpinner = false
            self.refreshRosterRow.isEnabled = true

            if let error = error {
                let alert = UIAlertController(title: "Couldn't refresh roster",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in self.onRefreshRoster() })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(alert, animated: true)
                return
            }

            let root = object as? [String: Any]
            let attributes = (root?["data"] as? [String: Any])?["attributes"] as? [String: Any]
            currentCourse.dataEntryGroups = attributes?["dataEntryGroups"]

            let included = root?["included"] as? [[String: Any]] ?? []
            EffortModel.mr_reconcile(fromIncluded: included, ofType: "efforts")
            currentCourse.monitorPacers = attributes?["monitorPacers"] as? NSNumber

            var eventIdsAndSplits = [String: [Any]]()
            var eventShortNames = [String: String]()
            for dict in included where (dict["type"] as? String) == "events" {
                guard let eventId = dict["id"] as? String else { continue }
                let attrs = dict["attributes"] as? [String: Any]
                if let shortName = attrs?["shortName"] as? String { eventShortNames[eventId] = shortName }
                var arr = eventIdsAndSplits[eventId] ?? []
                if let psn = attrs?["parameterizedSplitNames"] { arr.append(psn) }
                eventIdsAndSplits[eventId] = arr
            }
            currentCourse.eventIdsAndSplits = eventIdsAndSplits
            currentCourse.eventShortNames = eventShortNames

            NSManagedObjectContext.mr_saveDefaultContext()
            OSTToast.show(message: "Roster updated.", success: true)
        }
    }

    @objc private func onChangeStation() {
        let app = AppDelegate.getInstance()
        app?.rightMenuVC.toggleRightSideMenuCompletion {
            let event = OSTEventSelectionViewController(nibName: nil, bundle: nil)
            event.changeStation = true
            app?.rightMenuVC.centerViewController?.present(event, animated: true)
        }
    }

    @objc private func onAppearance() {
        BottomSheetPicker.present(from: self, title: "Appearance",
                                  options: ["System", "Light", "Dark"],
                                  selected: AppearanceController.shared.mode.displayName) { [weak self] choice in
            let mode: AppearanceMode
            switch choice {
            case "Light": mode = .light
            case "Dark":  mode = .dark
            default:      mode = .system
            }
            AppearanceController.shared.mode = mode
            self?.appearanceRow.detailText = mode.displayName
        }
    }

    @objc private func onAbout() {
        AppDelegate.getInstance()?.showAbout()
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    // MARK: - Logout

    @objc private func onLogout() { ostPresentLogoutFlow() }

    // MARK: - Badge + sync observer (override the Obj-C base)

    override func updateSyncBadge() {
        super.updateSyncBadge()
        reviewSyncRow.badgeCount = shouldShowBadge ? (Int(badge as String? ?? "0") ?? 0) : 0
    }

    override func syncManagerDidStartSynchronization(_ manager: AutoSyncController!) {
        super.syncManagerDidStartSynchronization(manager)
        reviewSyncRow.showsSpinner = true
    }

    override func syncManagerDidFinishSynchronization(_ manager: AutoSyncController!) {
        super.syncManagerDidFinishSynchronization(manager)
        reviewSyncRow.showsSpinner = false
    }

    override func syncManager(_ manager: AutoSyncController!, didFinishSynchronizationWithErrors errors: [Error]!, alternateServer: Bool) {
        super.syncManager(manager, didFinishSynchronizationWithErrors: errors, alternateServer: alternateServer)
        reviewSyncRow.showsSpinner = false
    }
}
