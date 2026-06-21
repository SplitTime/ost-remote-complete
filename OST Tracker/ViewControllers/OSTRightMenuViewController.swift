// OST Tracker/ViewControllers/OSTRightMenuViewController.swift
import UIKit

/// Right-side navigation drawer, rebuilt onto the design system: a clean themed
/// list (no background photo), built programmatically. Subclasses the Obj-C
/// `OSTBaseViewController` for the unsynced-count badge + AutoSync observer.
/// Hosted by `OSTDrawerContainer` as its `rightMenuViewController`.
@objc(OSTRightMenuViewController)
final class OSTRightMenuViewController: OSTBaseViewController {

    private let liveEntryRow  = MenuRow(title: "Live Entry")
    private let reviewSyncRow = MenuRow(title: "Review / Sync")
    private let crossCheckRow = MenuRow(title: "Cross Check")
    private let liveReadsRow  = MenuRow(title: "Live Reads")
    private let raceStatusRow = MenuRow(title: "Race Status")
    private let utilitiesRow  = MenuRow(title: "Utilities")
    private let autoSyncSwitch = UISwitch()

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
        raceStatusRow.addTarget(self, action: #selector(onRaceStatus), for: .touchUpInside)
        utilitiesRow.addTarget(self, action: #selector(onUtilities), for: .touchUpInside)

        let rows: [MenuRow] = [liveEntryRow, reviewSyncRow, crossCheckRow,
                               liveReadsRow, raceStatusRow, utilitiesRow]
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

        let autoLabel = UILabel()
        autoLabel.text = "Auto Sync"
        autoLabel.font = Theme.Font.field
        autoLabel.textColor = Theme.label
        autoSyncSwitch.isOn = AutoSyncController.shared.autoSyncEnabled
        autoSyncSwitch.addTarget(self, action: #selector(onAutoSyncSwitch(_:)), for: .valueChanged)
        let autoRow = UIStackView(arrangedSubviews: [autoLabel, UIView(), autoSyncSwitch])
        autoRow.alignment = .center

        let content = UIStackView(arrangedSubviews: [closeRow, brandRow, card])
        content.axis = .vertical
        content.spacing = 16
        content.setCustomSpacing(20, after: brandRow)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        autoRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(autoRow)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            autoRow.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            autoRow.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            autoRow.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
        ])
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.separator
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: - Actions (behavior identical to the former Obj-C menu)

    @objc private func onClose() {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        if let tracker = AppDelegate.getInstance()?.rightMenuVC.centerViewController as? OSTRunnerTrackerViewController {
            tracker.txtBibNumber.becomeFirstResponder()
        }
    }

    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onReviewSync() {
        AppDelegate.getInstance()?.showReview()
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onCrossCheck() {
        let storyboard = UIStoryboard(name: "CrossCheck", bundle: nil)
        if let controller = storyboard.instantiateInitialViewController() {
            AppDelegate.getInstance()?.rightMenuVC.centerViewController = controller
            AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        }
    }

    @objc private func onLiveReads() {
        AppDelegate.getInstance()?.rightMenuVC.centerViewController = OSTLiveReadsViewController()
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onRaceStatus() {
        AppDelegate.getInstance()?.rightMenuVC.centerViewController = OSTRaceStatusViewController()
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onUtilities() {
        AppDelegate.getInstance()?.showUtilities()
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onAutoSyncSwitch(_ sender: UISwitch) {
        AutoSyncController.shared.autoSyncEnabled = sender.isOn
    }

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
