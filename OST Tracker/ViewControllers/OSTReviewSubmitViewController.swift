//
//  OSTReviewSubmitViewController.swift
//  OST Tracker
//
//  Programmatic DesignSystem rewrite. Header (event name + Export + sort row),
//  a grouped table of entries, and a pinned full-width Sync button with an inline
//  progress bar; completion is signalled by OSTToast. All sync/export/edit logic
//  is preserved from the prior XIB-driven version.
//

import UIKit
import CoreData

private extension ReviewEntryDisplay {
    init(entry: EntryModel) {
        self.init(displayTime: entry.displayTime,
                  fullName: entry.fullName,
                  bibNumber: entry.bibNumber,
                  bitKey: entry.bitKey,
                  submitted: entry.submitted?.boolValue ?? false,
                  withPacer: entry.withPacer,
                  stoppedHere: entry.stoppedHere)
    }
}

@objc(OSTReviewSubmitViewController)
class OSTReviewSubmitViewController: OSTBaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let titleLabel = UILabel()
    private let menuBtn = UIButton(type: .system)
    private let badgeView = UILabel()
    private let exportButton = UIButton(type: .system)
    private let sortButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let syncButton = PrimaryButton(title: "All Synced", role: .primary)
    private let progressBar = UIProgressView(progressViewStyle: .default)

    // entries[section] is the sorted entries for splitTitles[section]
    private var entries: [[EntryModel]] = []
    private var splitTitles: [String] = []

    private let sortOptions = ["Name", "Time Displayed", "Time Entered", "Bib #"]
    private var sortSelection = 2 // default: Time Entered
    private static let sortSelectionDefaultsKey = "reviewScreenPicklistValue"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()

        // Hand the base VC its badge + menu button so updateSyncBadge keeps working.
        menuButton = menuBtn
        badgeLabel = badgeView

        if let stored = UserDefaults.standard.object(forKey: Self.sortSelectionDefaultsKey) as? NSNumber {
            sortSelection = stored.intValue
        }
        updateSortButtonTitle()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        tableView.register(ReviewEntryCell.self, forCellReuseIdentifier: ReviewEntryCell.reuseID)
        tableView.register(ReviewSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: ReviewSectionHeaderView.reuseID)

        AutoSyncController.shared.showToastOnCompletion = true
        updateSyncButtonState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        updateSyncBadge()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AutoSyncController.shared.showToastOnCompletion = true
    }

    // MARK: - UI

    private func buildUI() {
        titleLabel.font = Theme.Font.brand
        titleLabel.textColor = Theme.label
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        menuBtn.setTitle("Menu \u{2630}", for: .normal) // ☰ — opens the right-side drawer
        menuBtn.setTitleColor(Theme.tint, for: .normal)
        menuBtn.titleLabel?.font = Theme.Font.button
        menuBtn.addTarget(self, action: #selector(onRightMenu), for: .touchUpInside)

        // Standard iOS share glyph (bundled asset; SF Symbols need iOS 13+). The
        // source PNG is 512px, so render it as a tinted template at a fixed size.
        exportButton.setImage(UIImage(named: "share-icon")?.withRenderingMode(.alwaysTemplate), for: .normal)
        exportButton.tintColor = Theme.tint
        exportButton.imageView?.contentMode = .scaleAspectFit
        exportButton.accessibilityLabel = "Export"
        exportButton.addTarget(self, action: #selector(onExport(_:)), for: .touchUpInside)
        exportButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        exportButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

        // Title leading; Export + Menu on the trailing edge (the hamburger opens the
        // right-side drawer), matching the other screens' header convention.
        let headerRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), exportButton, menuBtn])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12

        // Count badge pinned to the menu button's top-trailing corner.
        badgeView.font = .systemFont(ofSize: 12, weight: .bold)
        badgeView.textColor = .white
        badgeView.backgroundColor = Theme.destructive
        badgeView.textAlignment = .center
        badgeView.layer.cornerRadius = 9
        badgeView.clipsToBounds = true
        badgeView.isHidden = true
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badgeView)

        sortButton.contentHorizontalAlignment = .left
        sortButton.setTitleColor(Theme.label, for: .normal)
        sortButton.titleLabel?.font = Theme.Font.field
        sortButton.backgroundColor = Theme.fieldFill
        sortButton.layer.cornerRadius = Theme.Metric.cornerRadius
        sortButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        sortButton.heightAnchor.constraint(equalToConstant: Theme.Metric.fieldHeight).isActive = true
        sortButton.addTarget(self, action: #selector(onSortTapped), for: .touchUpInside)

        tableView.translatesAutoresizingMaskIntoConstraints = false

        progressBar.progressTintColor = Theme.tint
        progressBar.trackTintColor = Theme.separator
        progressBar.isHidden = true

        syncButton.addTarget(self, action: #selector(onSubmit(_:)), for: .touchUpInside)

        let bottomBar = UIStackView(arrangedSubviews: [progressBar, syncButton])
        bottomBar.axis = .vertical
        bottomBar.spacing = 8

        let topStack = UIStackView(arrangedSubviews: [headerRow, sortButton])
        topStack.axis = .vertical
        topStack.spacing = 12
        topStack.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(topStack)
        view.addSubview(tableView)
        view.addSubview(bottomBar)

        let guide = view.safeAreaLayoutGuide
        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            topStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            topStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),

            tableView.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -8),

            bottomBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            bottomBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),
            bottomBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),

            badgeView.topAnchor.constraint(equalTo: menuBtn.topAnchor, constant: -4),
            badgeView.leadingAnchor.constraint(equalTo: menuBtn.trailingAnchor, constant: -14),
            badgeView.heightAnchor.constraint(equalToConstant: 18),
            badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
        ])
    }

    private func updateSortButtonTitle() {
        sortButton.setTitle("Sort:  \(sortOptions[sortSelection])  \u{25BE}", for: .normal) // ▾
    }

    // MARK: - Data

    private func loadData() {
        entries = []
        guard let course = CurrentCourse.getCurrentCourse(), let courseId = course.eventId else { return }

        let all = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@", courseId)) as? [EntryModel]) ?? []
        // Group once in memory instead of re-fetching per split (was N+1 fetches).
        let bySplit = Dictionary(grouping: all) { $0.splitName ?? "" }
        var titles = Array(bySplit.keys.filter { !$0.isEmpty })

        // Surface the current aid station's split at the top.
        if let currentSplit = course.splitName, let idx = titles.firstIndex(of: currentSplit) {
            titles.remove(at: idx)
            titles.insert(currentSplit, at: 0)
        }
        splitTitles = titles

        var sortKey = "fullName"
        var ascending = true
        switch sortSelection {
        case 1: sortKey = "entryTime"; ascending = false
        case 2: sortKey = "timeEntered"; ascending = false
        case 3: sortKey = "bibNumberDecimal"
        default: break // 0 -> fullName ascending
        }

        for title in splitTitles {
            let splitEntries = bySplit[title] ?? []
            let sorted = (splitEntries as NSArray).sortedArray(using: [NSSortDescriptor(key: sortKey, ascending: ascending)]) as? [EntryModel] ?? splitEntries
            entries.append(sorted)
        }

        titleLabel.text = course.eventName
        tableView.reloadData()
        updateSyncButtonState()
    }

    /// The entries the Sync button submits for the current course: everything
    /// unsynced. Single source of truth for the Sync count, the Submit action, and
    /// (matching predicate) the base class's badge count.
    private func entriesToSync() -> [EntryModel] {
        guard let courseId = CurrentCourse.getCurrentCourse()?.eventId else { return [] }
        return (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@ && submitted == NIL", courseId)) as? [EntryModel]) ?? []
    }

    private func unsyncedCount() -> Int { entriesToSync().count }

    private func updateSyncButtonState() {
        let isSyncing = AutoSyncController.shared.isSyncing
        progressBar.isHidden = !isSyncing
        if isSyncing {
            syncButton.setTitle("Syncing\u{2026}", for: .normal)
            syncButton.isEnabled = false
            syncButton.alpha = 0.7
        } else {
            let count = unsyncedCount()
            syncButton.setTitle(ReviewSyncButton.title(unsyncedCount: count), for: .normal)
            syncButton.isEnabled = ReviewSyncButton.isEnabled(unsyncedCount: count, isSyncing: false)
            syncButton.alpha = syncButton.isEnabled ? 1 : 0.7
        }
    }

    // MARK: - Badge

    override func updateSyncBadge() {
        // super sets badgeLabel.text + hidden + shape on our badgeView label.
        super.updateSyncBadge()
    }

    // MARK: - Sync manager delegate

    override func syncManagerDidStartSynchronization(_ manager: AutoSyncController) {
        super.syncManagerDidStartSynchronization(manager)
        updateSyncButtonState()
    }

    override func syncManager(_ manager: AutoSyncController, progress: CGFloat) {
        super.syncManager(manager, progress: progress)
        progressBar.setProgress(Float(progress), animated: true)
    }

    override func syncManagerDidFinishSynchronization(_ manager: AutoSyncController) {
        super.syncManagerDidFinishSynchronization(manager)
        loadData()
        updateSyncButtonState()
        updateSyncBadge()
    }

    override func syncManager(_ manager: AutoSyncController, didFinishSynchronizationWithErrors errors: [Error], alternateServer: Bool) {
        super.syncManager(manager, didFinishSynchronizationWithErrors: errors, alternateServer: alternateServer)
        updateSyncButtonState()

        let nsErrors = errors.map { $0 as NSError }
        if !alternateServer {
            ostPresentAlert(title: "Unable to sync", message: nsErrors.first?.errorsFromDictionary() ?? "")
        } else {
            let message1: String
            if let error1 = nsErrors.first {
                message1 = error1.code == -1009 ? "The device is not connected" : "Error: \(error1.errorsFromDictionary() ?? "")"
            } else {
                message1 = "Unknown error"
            }
            let message2 = nsErrors.count > 1 ? "Error: \(nsErrors[1].errorsFromDictionary() ?? "")" : "Unknown error"
            ostPresentAlert(title: "Unable to sync",
                            message: "Primary server returned: \(message1), alternate server: \(message2)")
        }
        loadData()
    }

    // MARK: - Actions

    @objc private func onSortTapped() {
        BottomSheetPicker.present(from: self, title: "Sort By", options: sortOptions,
                                  selected: sortOptions[sortSelection]) { [weak self] choice in
            guard let self = self, let idx = self.sortOptions.firstIndex(of: choice) else { return }
            self.sortSelection = idx
            UserDefaults.standard.set(idx, forKey: Self.sortSelectionDefaultsKey)
            self.updateSortButtonTitle()
            self.loadData()
        }
    }

    @objc func onRightMenu() {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    /// `entries` is a list of split sections, so `entries.isEmpty` is true only
    /// when there are no sections at all. A section with zero rows still means
    /// nothing was entered, so check every section for rows.
    private var noEntriesEntered: Bool { entries.allSatisfy { $0.isEmpty } }

    @objc func onSubmit(_ sender: Any) {
        UIDevice.current.playInputClick()

        let toSubmit = entriesToSync()
        if toSubmit.isEmpty {
            ostPresentAlert(title: "", message: noEntriesEntered ? "No times have been entered." : "All times have been synced.")
            return
        }

        progressBar.setProgress(0, animated: false)
        AutoSyncController.shared.syncEntries(toSubmit)
        updateSyncButtonState()
    }

    @objc func onExport(_ sender: Any) {
        guard let courseId = CurrentCourse.getCurrentCourse()?.eventId else { return }
        let toExport = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@", courseId)) as? [EntryModel]) ?? []
        if toExport.isEmpty {
            ostPresentAlert(title: "", message: noEntriesEntered ? "No times have been entered." : "All times have been synced.")
            return
        }

        let alert = UIAlertController(title: "",
                                      message: "This feature exports data to the local device only. It does not sync with OpenSplitTime.org",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel) { [weak self] _ in
            self?.exportCSV(toExport)
        })
        present(alert, animated: true)
    }

    private func exportCSV(_ entries: [EntryModel]) {
        // RFC-4180 field escaping: quote when the value contains a comma, quote or
        // newline, doubling any embedded quotes.
        func csvField(_ value: String) -> String {
            guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        var rows = [["splitName", "subSplitKind", "bibNumber", "enteredTime", "withPacer", "stoppedHere", "source"]]
        for entry in entries {
            rows.append([entry.splitName ?? "", entry.bitKey ?? "", entry.bibNumber ?? "",
                         entry.absoluteTime ?? "", entry.withPacer ?? "", entry.stoppedHere ?? "", entry.source ?? ""])
        }
        let csv = rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\n")

        let activityVC = UIActivityViewController(activityItems: [csv], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.sourceView = view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.width / 2, y: view.bounds.height / 4, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }

    // MARK: - UITableViewDataSource / Delegate

    func numberOfSections(in tableView: UITableView) -> Int {
        return entries.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries[section].count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReviewSectionHeaderView.reuseID) as? ReviewSectionHeaderView
        header?.configure(title: "\(splitTitles[section]) Entries:")
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReviewEntryCell.reuseID, for: indexPath) as! ReviewEntryCell
        cell.configure(with: ReviewEntryDisplay(entry: entries[indexPath.section][indexPath.row]))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = entries[indexPath.section][indexPath.row]

        if AutoSyncController.shared.isSyncingEntry(entry) {
            ostPresentAlert(title: "Unable to edit time", message: "Time is being synced.")
            return
        }

        if entry.submitted?.boolValue == true {
            let alert = UIAlertController(title: "",
                                          message: "Time has already been synced. Create a replacement time?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "No", style: .cancel))
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
                guard let self = self else { return }
                let editVC = OSTEditEntryViewController(nibName: nil, bundle: nil)
                editVC.entryHasBeenUpdatedBlock = { [weak self] _ in
                    self?.loadData()
                    self?.updateSyncBadge()
                }
                editVC.creatingNew = true
                self.present(editVC, animated: true)
                editVC.configure(withEntry: entry)
            })
            present(alert, animated: true)
            return
        }

        let editVC = OSTEditEntryViewController(nibName: nil, bundle: nil)
        editVC.entryHasBeenDeletedBlock = { [weak self] in
            self?.loadData()
            self?.updateSyncBadge()
        }
        editVC.entryHasBeenUpdatedBlock = { [weak self] _ in
            self?.loadData()
            self?.updateSyncBadge()
        }
        present(editVC, animated: true)
        editVC.configure(withEntry: entry)
    }
}
