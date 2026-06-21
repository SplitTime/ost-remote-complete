//
//  OSTCrossCheckViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 2). Keeps the CrossCheck.storyboard (the VC
//  resolves via @objc) and the Obj-C cell/header/footer/checkmark classes. Still
//  uses MagicalRecord + the Obj-C network manager via bridging. DejalBezelActivity
//  View replaced by the shared native blocking spinner. The iPhone-X/XR-only +7pt
//  nudge was dropped (never fires on the iOS-12 device fleet).
//

import UIKit
import CoreData

@objc(OSTCrossCheckViewController)
class OSTCrossCheckViewController: OSTBaseViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    private enum Filter: Int {
        case all = 0, recorded = 1, droppedHere = 2, expected = 3, notExpected = 4
    }

    // MARK: - Outlets
    @IBOutlet weak var popupOverlay: UIView!
    @IBOutlet weak var popupView: UIView!
    @IBOutlet weak var btnReviewEntries: UIButton!
    @IBOutlet weak var lblPupupEntryName: UILabel!
    @IBOutlet weak var bulkSelectMenuView: UIView!
    @IBOutlet weak var footerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var btnBulkSelect: UIButton!
    @IBOutlet weak var swchPopupExpected: UISwitch!
    @IBOutlet weak var popupCrossCheckContainer: UIView!
    @IBOutlet weak var popupSegmentedView: UIView!
    @IBOutlet weak var crossCheckCollection: UICollectionView!
    @IBOutlet weak var popupCellStatusLabel: UILabel!
    @IBOutlet weak var popupAidIcon: UIImageView!
    @IBOutlet weak var popupBibNumber: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var popupDroppedHereIcon: UIImageView!
    @IBOutlet weak var btnRightMenu: UIButton!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var selectedFilterView: OSTCheckmarkView!
    @IBOutlet var checkMarkFilters: [OSTCheckmarkView]!

    // MARK: - State
    private var efforts: [EffortModel] = []
    private var currentEfforts: [EffortModel] = []
    private var popupEffort: EffortModel?
    private var popupCrossCheckModel: CrossCheckEntriesModel?
    private var bulkSelect = false
    private var splitName = ""
    private var filter: Filter = .all

    // MARK: - Lifecycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostApplySafeAreaFix()
        ostPositionBadgeAtMenu()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        popupView.frame.origin.y = view.frame.maxY

        adjustCrossCheckCollectionBottomInset()

        filter = Filter(rawValue: selectedFilterView.tag) ?? .all
        selectedFilterView.isSelected = true

        popupCrossCheckContainer.layer.cornerRadius = 6
        let currentCourseSplitName = CurrentCourse.getCurrentCourse()?.splitName
        splitName = currentCourseSplitName ?? ""

        for entrie in (CurrentCourse.getCurrentCourse()?.dataEntryGroups as? [[String: Any]]) ?? [] {
            let entries = entrie["entries"] as? [[String: Any]] ?? []
            if entries.count == 1 { continue }
            if (entrie["title"] as? String) == currentCourseSplitName {
                let k0 = entries[0]["subSplitKind"] as? String
                let k1 = entries[1]["subSplitKind"] as? String
                if (k0 == "in" && k1 == "in") || (k0 == "out" && k1 == "out") {
                    splitName = entries[0]["splitName"] as? String ?? splitName
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        adjustCrossCheckCollectionBottomInset()
        reloadData()
    }

    // MARK: - Data

    private func fetchNotExpected(completion: @escaping () -> Void) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        OSTBackend.shared.fetchNotExpected(groupId: CurrentCourse.getCurrentCourse()?.eventGroupId ?? "",
                                           splitName: splitName) { [weak self] object, error in
            guard let self = self else { return }
            if error == nil,
               let bibNumbers = (object as? NSDictionary)?.value(forKeyPath: "data.bib_numbers") as? [Any] {
                self.bulkNotExpected(bibNumbers: bibNumbers)
            }
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            completion()
        }
    }

    private func reloadData() {
        ostShowBlockingSpinner()

        DispatchQueue.main.async {
            self.efforts = (EffortModel.mr_findAllSorted(by: "bibNumber", ascending: true,
                                                         with: NSPredicate(format: "bibNumber != nil")) as? [EffortModel]) ?? []
            // Fold the not-expected fetch into this reload: mark not-expected first,
            // then filter and render exactly once. The old code fired this fetch
            // and-forgot, so its async completion reloaded the collection after the
            // spinner had hidden and the filter had been applied — racing and
            // clobbering the rendered view.
            self.fetchNotExpected { [weak self] in
                guard let self = self else { return }
                var entriesThatShouldBeHere: [EffortModel] = []
                for effort in self.efforts {
                    if effort.checkIfEffortShouldBe(inSplit: CurrentCourse.getCurrentCourse()?.splitName, selectedSplitName: self.splitName) {
                        _ = effort.expected(withSplitName: self.splitName)
                        entriesThatShouldBeHere.append(effort)
                    }
                }
                self.efforts = entriesThatShouldBeHere
                self.applyFilter()                 // setFiltersQuantities + collection reload
                self.ostHideBlockingSpinner()
            }
        }
    }

    private func recordedEfforts(droppedHere: Bool) -> [EffortModel] {
        var filtered: [EffortModel] = []
        for effort in efforts {
            let entries = effort.entries(forSplitName: splitName) ?? []
            if entries.count > 0 {
                if let stopped = effort.stoppedHere, stopped.boolValue {
                    if droppedHere { filtered.append(effort) }
                } else {
                    if !droppedHere { filtered.append(effort) }
                }
            }
        }
        return filtered
    }

    private func nonRecordedEfforts(includeExpected: Bool) -> [EffortModel] {
        var filtered: [EffortModel] = []
        for effort in efforts {
            let entries = effort.entries(forSplitName: splitName) ?? []
            if entries.count == 0 {
                let value = effort.expected(withSplitName: splitName)
                let expected = value == nil || value == NSNumber(value: true)
                if (includeExpected && expected) || (!includeExpected && !expected) {
                    filtered.append(effort)
                }
            }
        }
        return filtered
    }

    private func setFiltersQuantities() {
        for checkMark in checkMarkFilters {
            switch Filter(rawValue: checkMark.tag) {
            case .all:         checkMark.number = "(\(efforts.count))"
            case .recorded:    checkMark.number = "(\(recordedEfforts(droppedHere: false).count))"
            case .droppedHere: checkMark.number = "(\(recordedEfforts(droppedHere: true).count))"
            case .expected:    checkMark.number = "(\(nonRecordedEfforts(includeExpected: true).count))"
            case .notExpected: checkMark.number = "(\(nonRecordedEfforts(includeExpected: false).count))"
            case .none:        break
            }
        }
    }

    private func applyFilter() {
        switch filter {
        case .all:         currentEfforts = efforts
        case .recorded:    currentEfforts = recordedEfforts(droppedHere: false)
        case .droppedHere: currentEfforts = recordedEfforts(droppedHere: true)
        case .expected:    currentEfforts = nonRecordedEfforts(includeExpected: true)
        case .notExpected: currentEfforts = nonRecordedEfforts(includeExpected: false)
        }
        setFiltersQuantities()
        crossCheckCollection.reloadData()
    }

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentEfforts.count
    }

    /// An effort with no recorded entry at this split is in the Expected /
    /// Not-Expected state — the only state that's bulk-selectable and shows the
    /// expected toggle. Derive it from the model rather than the rendered cell label
    /// (which breaks on any copy/localization change to the status text).
    private func isUnrecorded(_ effort: EffortModel) -> Bool {
        (effort.entries(forSplitName: splitName) ?? []).isEmpty
    }

    /// Mirrors the cell's Expected-vs-Not-Expected split: Not-Expected only when
    /// the effort is explicitly flagged `expected == NO` for this split.
    private func isExpectedHere(_ effort: EffortModel) -> Bool {
        let expected = effort.expected(withSplitName: splitName)
        let explicitlyNotExpected = expected?.isEqual(NSNumber(value: false)) ?? false
        return !explicitlyNotExpected
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OSTCrossCheckCell", for: indexPath) as! OSTCrossCheckCell
        cell.splitName = splitName
        cell.configure(withEffort: currentEfforts[indexPath.row])

        if bulkSelect {
            cell.noBulkSelectView.isHidden = isUnrecorded(currentEfforts[indexPath.row])
        }
        if currentEfforts[indexPath.row].bulkSelected {
            cell.noBulkSelectView.isHidden = false
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if bulkSelect {
            let effort = currentEfforts[indexPath.row]
            guard let cell = collectionView.cellForItem(at: indexPath) as? OSTCrossCheckCell else { return }
            guard isUnrecorded(effort) else { return }
            effort.bulkSelected.toggle()
            cell.configure(withEffort: effort)
            return
        }

        popupEffort = currentEfforts[indexPath.row]
        lblPupupEntryName.text = popupEffort?.fullName

        guard let cell = collectionView.cellForItem(at: indexPath) as? OSTCrossCheckCell else { return }
        popupAidIcon.isHidden = cell.imgAid.isHidden
        popupDroppedHereIcon.isHidden = cell.imgDroppedHere.isHidden

        popupCrossCheckContainer.backgroundColor = cell.backgroundColor
        popupBibNumber.textColor = cell.lblBibNumber.textColor
        popupCellStatusLabel.backgroundColor = cell.lblStatus.backgroundColor
        popupBibNumber.text = cell.lblBibNumber.text
        popupCellStatusLabel.text = cell.lblStatus.text // display mirror only

        if isUnrecorded(popupEffort!) {
            popupSegmentedView.isHidden = false
            btnReviewEntries.isHidden = true
            swchPopupExpected.isOn = isExpectedHere(popupEffort!)
        } else {
            popupSegmentedView.isHidden = true
            btnReviewEntries.isHidden = false
        }
        showPopup()
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "OSTCrossCheckHeader", for: indexPath) as! OSTCrossCheckHeader

            headerView.lblStationName.text = CurrentCourse.getCurrentCourse()?.splitName
            headerView.segLocation.isHidden = true
            headerView.lblStationName.isHidden = false

            for entrie in (CurrentCourse.getCurrentCourse()?.dataEntryGroups as? [[String: Any]]) ?? [] {
                let entries = entrie["entries"] as? [[String: Any]] ?? []
                if entries.count == 1 { continue }
                if (entrie["title"] as? String) == CurrentCourse.getCurrentCourse()?.splitName {
                    let k0 = entries[0]["subSplitKind"] as? String
                    let k1 = entries[1]["subSplitKind"] as? String
                    if (k0 == "in" && k1 == "in") || (k0 == "out" && k1 == "out") {
                        headerView.segLocation.isHidden = false
                        headerView.lblStationName.isHidden = true
                        headerView.segLocation.setTitle(entries[0]["splitName"] as? String, forSegmentAt: 0)
                        headerView.segLocation.setTitle(entries[1]["splitName"] as? String, forSegmentAt: 1)
                        headerView.splitChange = { [weak self] newSplitName in
                            guard let self = self else { return }
                            self.splitName = newSplitName ?? ""
                            for effort in self.efforts { effort.clearVariables() }
                            self.reloadData()
                        }
                    } else {
                        headerView.segLocation.isHidden = true
                        headerView.lblStationName.isHidden = false
                    }
                }
            }
            return headerView
        }

        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "OSTCrossCheckFooter", for: indexPath)
    }

    // MARK: - Actions

    @IBAction func onFilter(_ checkmark: OSTCheckmarkView) {
        selectedFilterView?.isSelected = false
        filter = Filter(rawValue: checkmark.tag) ?? .all
        applyFilter()
        selectedFilterView = checkmark
    }

    @IBAction func changedSwich(_ sender: Any) {
    }

    @IBAction func onMenu(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @IBAction func onBulkSelect(_ sender: Any) {
        for effort in efforts { effort.bulkSelected = false }

        if bulkSelect {
            bulkSelect = false
            footerViewHeightConstraint.constant = 82
            btnBulkSelect.setTitle("Bulk Select", for: .normal)
            bulkSelectMenuView.isHidden = true
        } else {
            bulkSelect = true
            footerViewHeightConstraint.constant = 132
            btnBulkSelect.setTitle("Cancel", for: .normal)
            bulkSelectMenuView.isHidden = false
        }

        footerView.frame.origin.y = view.frame.height - footerView.frame.height
        adjustCrossCheckCollectionBottomInset()
        setFiltersQuantities()
        crossCheckCollection.reloadData()
    }

    private func adjustCrossCheckCollectionBottomInset() {
        crossCheckCollection.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: footerView.frame.height, right: 0)
    }

    @IBAction func onClosePopup(_ sender: Any) {
        if !swchPopupExpected.isHidden {
            if let model = popupCrossCheckModel {
                if swchPopupExpected.isOn {
                    model.mr_deleteEntity()
                    saveContext()
                    popupEffort?.expected = NSNumber(value: true)
                }
            } else if !swchPopupExpected.isOn {
                if let entry = CrossCheckEntriesModel.mr_createEntity() as? CrossCheckEntriesModel {
                    entry.bibNumber = popupEffort?.bibNumber?.stringValue
                    entry.splitName = splitName
                    entry.courseId = CurrentCourse.getCurrentCourse()?.eventId
                    saveContext()
                    popupEffort?.expected = NSNumber(value: false)
                }
            }
        }
        setFiltersQuantities()
        crossCheckCollection.reloadData()
        hidePopup()
    }

    private func hidePopup() {
        UIView.animate(withDuration: 0.25) {
            self.popupView.frame.origin.y = self.view.frame.maxY
            self.popupOverlay.alpha = 0
        }
    }

    @IBAction func onBulkExpected(_ sender: Any) {
        for effort in efforts where effort.bulkSelected {
            if let bib = effort.bibNumber?.stringValue,
               let entry = CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bib)) as? CrossCheckEntriesModel {
                entry.mr_deleteEntity()
                saveContext()
            }
            effort.expected = NSNumber(value: true)
        }
        applyFilter()
        onBulkSelect(self)
    }

    private func bulkNotExpected(bibNumbers: [Any]) {
        var notExpected: [EffortModel] = []
        for effort in efforts {
            // Recorded/Dropped efforts keep their current state regardless of the list.
            if (effort.entries(forSplitName: splitName) ?? []).count > 0 { continue }

            if let bib = effort.bibNumber, (bibNumbers as NSArray).contains(bib) {
                notExpected.append(effort)
            } else if let bib = effort.bibNumber?.stringValue,
                      let entry = CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bib)) as? CrossCheckEntriesModel {
                entry.mr_deleteEntity()
                saveContext()
                effort.expected = NSNumber(value: true)
            }
        }
        bulkNotExpected(efforts: notExpected)
    }

    private func bulkNotExpected(efforts: [EffortModel]) {
        for effort in efforts {
            guard let bib = effort.bibNumber?.stringValue else { continue }
            if CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bib)) as? CrossCheckEntriesModel == nil {
                if let entry = CrossCheckEntriesModel.mr_createEntity() as? CrossCheckEntriesModel {
                    entry.bibNumber = bib
                    entry.splitName = splitName
                    entry.courseId = CurrentCourse.getCurrentCourse()?.eventId
                    saveContext()
                    effort.expected = NSNumber(value: false)
                }
            }
        }
    }

    @IBAction func onBulkNotExpected(_ sender: Any) {
        let selected = efforts.filter { $0.bulkSelected }
        bulkNotExpected(efforts: selected)
        applyFilter()
        onBulkSelect(self)
    }

    @IBAction func onReviewEntries(_ sender: Any) {
        AppDelegate.getInstance()?.showReview()
    }

    private func showPopup() {
        let bib = popupEffort?.bibNumber?.stringValue ?? ""
        popupCrossCheckModel = CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bib)) as? CrossCheckEntriesModel
        UIView.animate(withDuration: 0.25) {
            self.popupView.frame.origin.y = self.view.frame.maxY - self.popupView.frame.height
            self.popupOverlay.alpha = 0.3
        }
    }

    // MARK: - Helpers

    private func crossCheckPredicate(bib: String) -> NSPredicate {
        NSPredicate(format: "bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",
                    bib, CurrentCourse.getCurrentCourse()?.eventId ?? "", splitName)
    }

    private func saveContext() {
        NSManagedObjectContext.mr_saveDefaultContext()
    }
}
