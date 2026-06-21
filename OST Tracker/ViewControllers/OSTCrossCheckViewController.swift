//  OSTCrossCheckViewController.swift
//  OST Tracker
//
//  Programmatic DesignSystem rebuild of the aid-station Cross Check board.
//  Top "Still out — Expected" list + Recorded/Dropped/Not-expected summary rows;
//  tap a bib for the action sheet, tap a summary row to drill in. Bulk-select and
//  the storyboard/Obj-C cell stack are retired. CoreData operations preserved.

import UIKit
import CoreData

@objc(OSTCrossCheckViewController)
class OSTCrossCheckViewController: OSTBaseViewController, UITableViewDataSource, UITableViewDelegate {

    // Sections
    private enum Section: Int, CaseIterable { case expected = 0, summary = 1 }

    // UI
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let menuBtn = UIButton(type: .system)
    private let badgeView = UILabel()
    private let inOutControl = UISegmentedControl(items: ["In", "Out"])
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let reviewButton = PrimaryButton(title: "Review \u{2192}", role: .primary)

    // Data
    private var efforts: [EffortModel] = []
    private var board = CrossCheckBoard(expected: [], recorded: [], droppedHere: [], notExpected: [])
    private var splitName = ""
    private var hasInOut = false
    private var inOutNames: [String] = []   // [inSplitName, outSplitName] when hasInOut

    // Summary rows shown in the summary section, in order.
    private var summaryItems: [(status: CrossCheckStatus, title: String, count: Int, rows: [CrossCheckRow])] {
        [
            (.recorded,    "Recorded",     board.recordedCount,    board.recorded),
            (.droppedHere, "Dropped here", board.droppedHereCount, board.droppedHere),
            (.notExpected, "Not expected", board.notExpectedCount, board.notExpected),
        ]
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()

        menuButton = menuBtn
        badgeLabel = badgeView

        resolveSplitName()
        configureInOutControl()

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        updateSyncBadge()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostPositionBadgeAtMenu()
    }

    // MARK: - UI

    private func buildUI() {
        titleLabel.text = "Cross Check"
        titleLabel.font = Theme.Font.brand
        titleLabel.textColor = Theme.label

        subtitleLabel.font = Theme.Font.field
        subtitleLabel.textColor = Theme.secondaryLabel

        menuBtn.configureAsMenuButton(target: self, action: #selector(onMenu))

        badgeView.font = .systemFont(ofSize: 12, weight: .bold)
        badgeView.textColor = .white
        badgeView.backgroundColor = Theme.destructive
        badgeView.textAlignment = .center
        badgeView.layer.cornerRadius = 9
        badgeView.clipsToBounds = true
        badgeView.isHidden = true
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badgeView)

        inOutControl.addTarget(self, action: #selector(onInOutChanged), for: .valueChanged)
        inOutControl.selectedSegmentIndex = 0

        let headerRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), menuBtn])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(CrossCheckExpectedCell.self, forCellReuseIdentifier: CrossCheckExpectedCell.reuseID)
        tableView.register(CrossCheckSummaryCell.self, forCellReuseIdentifier: CrossCheckSummaryCell.reuseID)
        tableView.register(ReviewSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: ReviewSectionHeaderView.reuseID)

        reviewButton.addTarget(self, action: #selector(onReview), for: .touchUpInside)

        let topStack = UIStackView(arrangedSubviews: [headerRow, subtitleLabel, inOutControl])
        topStack.axis = .vertical
        topStack.spacing = 10
        topStack.translatesAutoresizingMaskIntoConstraints = false

        let bottomBar = UIStackView(arrangedSubviews: [reviewButton])
        bottomBar.axis = .vertical
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

    // MARK: - Split / In-Out resolution (ported from legacy)

    private func resolveSplitName() {
        let currentName = CurrentCourse.getCurrentCourse()?.splitName
        splitName = currentName ?? ""
        inOutNames = []
        hasInOut = false
        for group in (CurrentCourse.getCurrentCourse()?.dataEntryGroups as? [[String: Any]]) ?? [] {
            let entries = group["entries"] as? [[String: Any]] ?? []
            if entries.count < 2 { continue }
            if (group["title"] as? String) == currentName {
                let k0 = entries[0]["subSplitKind"] as? String
                let k1 = entries[1]["subSplitKind"] as? String
                if (k0 == "in" && k1 == "in") || (k0 == "out" && k1 == "out") {
                    hasInOut = true
                    let n0 = entries[0]["splitName"] as? String ?? splitName
                    let n1 = entries[1]["splitName"] as? String ?? splitName
                    inOutNames = [n0, n1]
                    if splitName != n0 && splitName != n1 { splitName = n0 }
                }
            }
        }
    }

    private func configureInOutControl() {
        inOutControl.isHidden = !hasInOut
        if hasInOut, inOutNames.count == 2 {
            inOutControl.setTitle(inOutNames[0], forSegmentAt: 0)
            inOutControl.setTitle(inOutNames[1], forSegmentAt: 1)
            inOutControl.selectedSegmentIndex = (splitName == inOutNames[1]) ? 1 : 0
        }
    }

    @objc private func onInOutChanged() {
        guard hasInOut, inOutNames.count == 2 else { return }
        splitName = inOutNames[inOutControl.selectedSegmentIndex]
        for effort in efforts { effort.clearVariables() }
        reloadData()
    }

    // MARK: - Data

    private func reloadData() {
        ostShowBlockingSpinner()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.efforts = (EffortModel.mr_findAllSorted(by: "bibNumber", ascending: true,
                              with: NSPredicate(format: "bibNumber != nil")) as? [EffortModel]) ?? []
            self.fetchNotExpected { [weak self] in
                guard let self = self else { return }
                var here: [EffortModel] = []
                for effort in self.efforts {
                    if effort.checkIfEffortShouldBe(inSplit: CurrentCourse.getCurrentCourse()?.splitName,
                                                    selectedSplitName: self.splitName) {
                        _ = effort.expected(withSplitName: self.splitName)
                        here.append(effort)
                    }
                }
                self.efforts = here
                self.board = CrossCheckPresentation.build(from: here.map { self.facts(for: $0) })
                self.refreshSubtitle()
                self.tableView.reloadData()
                self.ostHideBlockingSpinner()
            }
        }
    }

    private func facts(for effort: EffortModel) -> EffortFacts {
        let entries = effort.entries(forSplitName: splitName) ?? []
        let hasEntries = entries.count > 0
        let isStopped = effort.stoppedHere?.boolValue ?? false
        let expectedValue = effort.expected(withSplitName: splitName)
        let isExpected = (expectedValue == nil) || (expectedValue == NSNumber(value: true))
        return EffortFacts(bib: effort.bibNumber?.stringValue ?? "",
                           name: effort.fullName ?? "",
                           hasEntries: hasEntries,
                           isStopped: isStopped,
                           isExpected: isExpected,
                           time: nil)
    }

    private func refreshSubtitle() {
        let station = CurrentCourse.getCurrentCourse()?.splitName ?? ""
        let total = board.expectedCount + board.recordedCount + board.droppedHereCount + board.notExpectedCount
        subtitleLabel.text = "\(station) \u{00B7} \(total) runners"
    }

    private func fetchNotExpected(completion: @escaping () -> Void) {
        OSTBackend.shared.fetchNotExpected(groupId: CurrentCourse.getCurrentCourse()?.eventGroupId ?? "",
                                           splitName: splitName) { [weak self] object, error in
            guard let self = self else { completion(); return }
            if error == nil,
               let bibNumbers = (object as? NSDictionary)?.value(forKeyPath: "data.bib_numbers") as? [Any] {
                self.applyServerNotExpected(bibNumbers: bibNumbers)
            }
            completion()
        }
    }

    // Server-driven not-expected marking (ported from legacy bulkNotExpected).
    private func applyServerNotExpected(bibNumbers: [Any]) {
        for effort in efforts {
            if (effort.entries(forSplitName: splitName) ?? []).count > 0 { continue }
            guard let bibStr = effort.bibNumber?.stringValue else { continue }
            let inList = (effort.bibNumber != nil) && (bibNumbers as NSArray).contains(effort.bibNumber!)
            if inList {
                if CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bibStr)) as? CrossCheckEntriesModel == nil,
                   let entry = CrossCheckEntriesModel.mr_createEntity() as? CrossCheckEntriesModel {
                    entry.bibNumber = bibStr
                    entry.splitName = splitName
                    entry.courseId = CurrentCourse.getCurrentCourse()?.eventId
                    saveContext()
                    effort.expected = NSNumber(value: false)
                }
            } else if let entry = CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bibStr)) as? CrossCheckEntriesModel {
                entry.mr_deleteEntity()
                saveContext()
                effort.expected = NSNumber(value: true)
            }
        }
    }

    // MARK: - Mark expected / not-expected (ported from legacy onClosePopup)

    private func setExpected(_ expected: Bool, forBib bib: String) {
        let existing = CrossCheckEntriesModel.mr_findFirst(with: crossCheckPredicate(bib: bib)) as? CrossCheckEntriesModel
        if expected {
            existing?.mr_deleteEntity()
            saveContext()
        } else if existing == nil, let entry = CrossCheckEntriesModel.mr_createEntity() as? CrossCheckEntriesModel {
            entry.bibNumber = bib
            entry.splitName = splitName
            entry.courseId = CurrentCourse.getCurrentCourse()?.eventId
            saveContext()
        }
        if let effort = efforts.first(where: { $0.bibNumber?.stringValue == bib }) {
            effort.expected = NSNumber(value: expected)
        }
        board = CrossCheckPresentation.build(from: efforts.map { facts(for: $0) })
        refreshSubtitle()
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func onMenu() {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onReview() {
        AppDelegate.getInstance()?.showReview()
    }

    private func presentSheet(for row: CrossCheckRow) {
        CrossCheckActionSheet.present(from: self,
                                      config: CrossCheckPresentation.sheetConfig(for: row),
                                      onSetExpected: { [weak self] expected in self?.setExpected(expected, forBib: row.bib) },
                                      onReviewEntries: { [weak self] in self?.onReview() })
    }

    // MARK: - UITableView

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .expected: return board.expectedCount
        case .summary:  return summaryItems.count
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .expected else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReviewSectionHeaderView.reuseID) as? ReviewSectionHeaderView
        header?.configure(title: "STILL OUT \u{2014} EXPECTED (\(board.expectedCount))")
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .expected:
            let cell = tableView.dequeueReusableCell(withIdentifier: CrossCheckExpectedCell.reuseID, for: indexPath) as! CrossCheckExpectedCell
            cell.configure(with: board.expected[indexPath.row])
            return cell
        case .summary:
            let item = summaryItems[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: CrossCheckSummaryCell.reuseID, for: indexPath) as! CrossCheckSummaryCell
            cell.configure(status: item.status, title: item.title, count: item.count)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .expected:
            presentSheet(for: board.expected[indexPath.row])
        case .summary:
            let item = summaryItems[indexPath.row]
            let groupVC = CrossCheckGroupViewController(
                title: item.title, rows: item.rows,
                onSetExpected: { [weak self] row, expected in self?.setExpected(expected, forBib: row.bib) },
                onReviewEntries: { [weak self] in self?.onReview() })
            present(groupVC, animated: true)
        }
    }

    // MARK: - Helpers (ported)

    private func crossCheckPredicate(bib: String) -> NSPredicate {
        NSPredicate(format: "bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",
                    bib, CurrentCourse.getCurrentCourse()?.eventId ?? "", splitName)
    }

    private func saveContext() {
        NSManagedObjectContext.mr_saveDefaultContext()
    }
}
