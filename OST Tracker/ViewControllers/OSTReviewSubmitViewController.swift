//
//  OSTReviewSubmitViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 2). Keeps the existing XIB via
//  @objc(OSTReviewSubmitViewController). Still uses the Obj-C sync manager,
//  MagicalRecord and IQDropDownTextField via bridging. OHAlertView -> native
//  UIAlertController. The dead `onSubmit_old:` / `submitEntries:` path (not wired
//  in the XIB) and the iPhone-X/XR-only +7pt nudge (never fires on the iOS-12
//  device fleet) were dropped during the port.
//

import UIKit
import CoreData
import MFSideMenu
import MagicalRecord

@objc(OSTReviewSubmitViewController)
class OSTReviewSubmitViewController: OSTBaseViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSyncing: UILabel!
    @IBOutlet var loadingView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var btnRightMenu: UIButton!
    @IBOutlet weak var lblYourDataIsSynced: UILabel!
    @IBOutlet weak var imgCheckMark: UIImageView!
    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var btnReturnToLiveEntry: UIButton!
    @IBOutlet weak var txtSortBy: OSTDropDownField!
    @IBOutlet weak var btnSync: UIButton!
    @IBOutlet weak var lblBadge: UILabel!
    @IBOutlet weak var syncIndicator: UIActivityIndicatorView!

    // entries[section] is the (sorted) entries for splitTitles[section]
    private var entries: [[EntryModel]] = []
    private var splitTitles: [String] = []

    // MARK: - Lifecycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostApplySafeAreaFix()
        ostPositionBadgeAtMenu()
        liftBottomBarAboveHomeIndicator()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: "OSTReviewTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "OSTReviewTableViewCell")

        txtSortBy.isOptionalDropDown = false
        txtSortBy.layer.borderColor = UIColor.white.cgColor
        txtSortBy.layer.borderWidth = 1
        txtSortBy.layer.cornerRadius = 3
        txtSortBy.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 20))
        txtSortBy.leftViewMode = .always
        txtSortBy.itemList = ["Name", "Time Displayed", "Time Entered", "Bib #"]

        if let stored = UserDefaults.standard.object(forKey: "reviewScreenPicklistValue") as? NSNumber {
            txtSortBy.selectedRow = stored.intValue
        } else {
            txtSortBy.selectedRow = 2
        }

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(onDoneSelectedSortBy(_:)))
        ]
        txtSortBy.inputAccessoryView = toolbar
        txtSortBy.removeInputAssistant()

        btnSync.setBackgroundImage(UIImage(named: "GrayButton"), for: .highlighted)
        // In the XIB the Sync button sits *behind* the table; on the short legacy
        // design it stuck out below, but on tall screens the grown table covers it
        // entirely. Lift it just above the table (still below the sync icon, which
        // is later in the order and rides on the button).
        view.insertSubview(btnSync, aboveSubview: tableView)

        lblBadge.layer.cornerRadius = lblBadge.frame.width / 2
        lblBadge.clipsToBounds = true

        OSTSyncManager.shared().showToastOnCompletion = true
        updateSyncButtonState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        loadingView.frame.size = view.frame.size
        loadData()
        updateSyncBadge()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        OSTSyncManager.shared().showToastOnCompletion = true
    }

    // The XIB lays the bottom action bar (Sync button + export/sync icons + badge
    // + spinner) with springs that leave it under / below the home indicator on
    // modern devices, and the shared safe-area pass actually pushes it *down*
    // (the Sync button is just under the 85%-width bottom-bar threshold). Lift the
    // whole bottom cluster uniformly so its lowest edge clears the safe area.
    // Works on the live frames (no outlets needed for the icons) and only ever
    // moves things up. NSLog instrumentation stays until verified on device.
    private func liftBottomBarAboveHomeIndicator() {
        var bottomInset = view.safeAreaInsets.bottom
        if bottomInset <= 0.5 { bottomInset = view.window?.safeAreaInsets.bottom ?? 0 }
        guard bottomInset > 0.5 else { return }

        let safeBottom = view.bounds.height - bottomInset - 8 // small gap above the indicator
        let fullScreen = view.bounds

        // 1) Lift the whole bottom band so its lowest edge clears the safe area.
        var cluster: [UIView] = []
        var lowestMaxY: CGFloat = 0
        for sub in view.subviews {
            if sub == tableView { continue }
            if sub is UIImageView && sub.frame == fullScreen { continue } // background
            if sub.frame.origin.y > view.bounds.height * 0.7 {            // bottom band
                cluster.append(sub)
                lowestMaxY = max(lowestMaxY, sub.frame.maxY)
            }
        }
        guard !cluster.isEmpty else { return }
        let delta = safeBottom - lowestMaxY
        if delta < -0.5 { for sub in cluster { sub.frame.origin.y += delta } }

        // 2) The shared safe-area pass treats the wide Sync button as a full-width
        //    bottom bar and lifts it, while the narrow icons get pushed down — which
        //    leaves the Sync button stranded ~70pt above the rest of the bar.
        //    Re-align it to the bar by matching the share button's vertical frame
        //    (same top and height) so the two read as one unified bottom bar.
        if let shareButton = cluster.first(where: { $0 is UIButton && $0 != btnSync }) {
            btnSync.frame.origin.y = shareButton.frame.origin.y
            btnSync.frame.size.height = shareButton.frame.size.height
        } else {
            btnSync.frame.origin.y = safeBottom - btnSync.frame.height
        }

        // The table now extends behind the bottom bar; inset it so the last rows
        // can scroll clear of the Sync button rather than hiding under it.
        let overlap = max(0, tableView.frame.maxY - btnSync.frame.minY)
        if abs(tableView.contentInset.bottom - overlap) > 0.5 {
            tableView.contentInset.bottom = overlap
            tableView.verticalScrollIndicatorInsets.bottom = overlap
        }
    }

    // MARK: - Data

    private func loadData() {
        entries = []
        guard let course = CurrentCourse.getCurrentCourse(), let courseId = course.eventId else { return }

        let all = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@", courseId)) as? [EntryModel]) ?? []
        var titlesSet = Set<String>()
        for entry in all { if let name = entry.splitName { titlesSet.insert(name) } }
        var titles = Array(titlesSet)

        // Surface the current aid station's split at the top.
        if let currentSplit = course.splitName, let idx = titles.firstIndex(of: currentSplit) {
            titles.remove(at: idx)
            titles.insert(currentSplit, at: 0)
        }
        splitTitles = titles

        var sortKey = "fullName"
        var ascending = true
        switch txtSortBy.selectedRow {
        case 1: sortKey = "entryTime"; ascending = false
        case 2: sortKey = "timeEntered"; ascending = false
        case 3: sortKey = "bibNumberDecimal"
        default: break // 0 -> fullName ascending
        }

        for title in splitTitles {
            let splitEntries = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@ && splitName == %@", courseId, title)) as? [EntryModel]) ?? []
            let sorted = (splitEntries as NSArray).sortedArray(using: [NSSortDescriptor(key: sortKey, ascending: ascending)]) as? [EntryModel] ?? splitEntries
            entries.append(sorted)
        }

        lblTitle.text = course.eventName
        tableView.reloadData()
    }

    // MARK: - Loading overlay

    private func showLoadingScreen() {
        loadingView.frame.size = view.frame.size
        view.addSubview(loadingView)
        view.bringSubviewToFront(loadingView)
        loadingView.alpha = 0
        UIView.animate(withDuration: 0.5) { self.loadingView.alpha = 1 }
    }

    private func showLoadingValues() {
        imgCheckMark.isHidden = true
        lblSuccess.isHidden = true
        lblYourDataIsSynced.isHidden = true
        btnReturnToLiveEntry.frame.origin.y = progressBar.frame.maxY + 20

        activityIndicator.startAnimating()
        lblSyncing.isHidden = false
        progressBar.isHidden = false

        OSTSyncManager.shared().showToastOnCompletion = false
    }

    private func showFinishLoadingValues() {
        imgCheckMark.isHidden = false
        lblSuccess.isHidden = false
        lblYourDataIsSynced.isHidden = false
        btnReturnToLiveEntry.frame.origin.y = lblSuccess.frame.maxY + 50

        activityIndicator.stopAnimating()
        lblSyncing.isHidden = true
        progressBar.isHidden = true
    }

    private func updateSyncButtonState() {
        let isSyncing = OSTSyncManager.shared().isSyncing
        btnSync.isEnabled = !isSyncing
        btnSync.alpha = isSyncing ? 0.7 : 1
        syncIndicator.isHidden = !isSyncing
        if isSyncing { showLoadingValues() } else { showFinishLoadingValues() }
    }

    // MARK: - Badge

    override func updateSyncBadge() {
        super.updateSyncBadge()
        lblBadge.isHidden = !shouldShowBadge
        lblBadge.text = badge as String?
        lblBadge.updateBadgeShape()
    }

    // MARK: - Sync manager delegate

    override func syncManagerDidStartSynchronization(_ manager: OSTSyncManager) {
        super.syncManagerDidStartSynchronization(manager)
        updateSyncButtonState()
    }

    override func syncManager(_ manager: OSTSyncManager, progress: CGFloat) {
        super.syncManager(manager, progress: progress)
        progressBar.progress = Float(progress)
    }

    override func syncManagerDidFinishSynchronization(_ manager: OSTSyncManager) {
        super.syncManagerDidFinishSynchronization(manager)
        updateSyncButtonState()
        if loadingView.superview != nil { showFinishLoadingValues() }
        loadData()
    }

    override func syncManager(_ manager: OSTSyncManager, didFinishSynchronizationWithErrors errors: [Error], alternateServer: Bool) {
        super.syncManager(manager, didFinishSynchronizationWithErrors: errors, alternateServer: alternateServer)
        updateSyncButtonState()

        let nsErrors = errors.map { $0 as NSError }
        if !alternateServer {
            ostPresentAlert(title: "Unable to sync", message: nsErrors.first?.errorsFromDictionary() ?? "")
        } else {
            let error1 = nsErrors[0]
            let message1 = error1.code == -1009 ? "The device is not connected" : "Error: \(error1.errorsFromDictionary() ?? "")"
            let error2 = nsErrors[1]
            let message2 = "Error: \(error2.errorsFromDictionary() ?? "")"
            ostPresentAlert(title: "Unable to sync",
                            message: "Primary server returned: \(message1), alternate server: \(message2)")
        }

        loadingView.removeFromSuperview()
        showFinishLoadingValues()
        loadData()
    }

    // MARK: - Actions

    @objc func onDoneSelectedSortBy(_ sender: Any) {
        UserDefaults.standard.set(txtSortBy.selectedRow, forKey: "reviewScreenPicklistValue")
        UserDefaults.standard.synchronize()
        txtSortBy.resignFirstResponder()
        loadData()
    }

    @IBAction func onRightMenu(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @IBAction func onReturnToLiveEntry(_ sender: Any) {
        activityIndicator.stopAnimating()
        loadingView.isHidden = true
        loadingView.removeFromSuperview()
        AppDelegate.getInstance()?.showTracker()
    }

    @IBAction func onSubmit(_ sender: Any) {
        UIDevice.current.playInputClick()
        guard let courseId = CurrentCourse.getCurrentCourse()?.eventId else { return }

        let toSubmit = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@ && submitted == NIL && bibNumber != %@", courseId, "-1")) as? [EntryModel]) ?? []
        if toSubmit.isEmpty {
            ostPresentAlert(title: "", message: entries.isEmpty ? "No times have been entered." : "All times have been synced.")
            return
        }

        OSTSyncManager.shared().syncEntries(toSubmit)
        showLoadingScreen()
        showLoadingValues()
    }

    @IBAction func onExport(_ sender: Any) {
        guard let courseId = CurrentCourse.getCurrentCourse()?.eventId else { return }
        let toExport = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@ && bibNumber != %@", courseId, "-1")) as? [EntryModel]) ?? []
        if toExport.isEmpty {
            ostPresentAlert(title: "", message: entries.isEmpty ? "No times have been entered." : "All times have been synced.")
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
        let header = OSTReviewSectionHeader.instanceFromNib() as? OSTReviewSectionHeader
        header?.lblTitle.text = "\(splitTitles[section]) Entries:"
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OSTReviewTableViewCell", for: indexPath) as! OSTReviewTableViewCell
        cell.selectionStyle = .none
        cell.configure(withEntry:entries[indexPath.section][indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = entries[indexPath.section][indexPath.row]

        if OSTSyncManager.shared().isSyncingEntry(entry) {
            ostPresentAlert(title: "Unable to edit time", message: "Time is been synced.")
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
                editVC.configure(withEntry:entry)
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
        editVC.configure(withEntry:entry)
    }
}
