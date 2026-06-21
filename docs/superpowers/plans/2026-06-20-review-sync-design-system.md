# Review / Sync DesignSystem Upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the XIB-driven Review/Sync screen with a fully programmatic screen on the shared DesignSystem, preserving all sync/export/edit logic.

**Architecture:** Pull all presentation logic into a pure, CoreData-free `ReviewPresentation.swift` (display mapping, label-role styling, sync-button title) that is unit-tested in isolation. Build design-system list views (`ReviewEntryCell`, `ReviewSectionHeaderView`) that map roles → `Theme` colors. Rewrite `OSTReviewSubmitViewController` programmatically with a header (event name + text Export button + sort row), a grouped table, and a pinned full-width Sync `PrimaryButton` with an inline progress bar; completion is signalled by `OSTToast`. Finally delete the legacy XIB/Obj-C cell+header files.

**Tech Stack:** Swift + UIKit (iOS 12 floor), programmatic Auto Layout, `Theme` design system, MagicalRecord-via-bridging CoreData, XCTest.

## Global Constraints

- iOS 12-safe: **no SF Symbols** (`UIImage(systemName:)` is iOS 13+); use `UIActivityIndicatorView(style: .gray)`; gate any iOS 13+ API behind `if #available`.
- All colors/fonts/metrics come from `Theme` — never hardcode colors.
- Tests: XCTest, `@testable import OST_Remote`, assert via public "test seam" properties (follow `OST TrackerTests/Swift/MenuRowTests.swift`).
- Preserve verbatim: the sort-key mapping and the `UserDefaults` key `"reviewScreenPicklistValue"`; the to-submit predicate `combinedCourseId == %@ && submitted == NIL && bibNumber != "-1"`; the CSV export flow; the edit-entry navigation; the base-VC badge wiring (`updateSyncBadge`, `menuButton`/`badgeLabel` outlets) and the `AutoSyncController` delegate overrides.
- Pacer/stopped icons keep the existing assets: `"Pacer Symbol Green"`/`"Pacer Symbol Blue"`, `"Green Hand"`/`"Red Hand"`.
- New `.swift` source files must be added to the **OST Remote** and **OST Remote Dev** targets; new test files to the **OST TrackerTests** target (see the pbxproj note in each task). Verify membership by a green build.
- Build/test command (substitute any available sim from `xcrun simctl list devices available`):
  `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
- Commit after each task.

---

### Task 1: `ReviewPresentation` — pure display/style/title logic

**Files:**
- Create: `OST Tracker/Swift/Review/ReviewPresentation.swift`
- Test: `OST TrackerTests/Swift/ReviewPresentationTests.swift`

**Interfaces:**
- Consumes: nothing (Foundation only; no UIKit, no CoreData).
- Produces:
  - `struct ReviewEntryDisplay: Equatable` with `init(displayTime:fullName:bibNumber:bitKey:submitted:withPacer:stoppedHere:)` and fields `time: String`, `name: String`, `bib: String?`, `inOut: String`, `isSynced: Bool`, `isBibMissing: Bool`, `showsPacer: Bool`, `showsStopped: Bool`.
  - `enum ReviewLabelRole { case normal, secondary, success, destructive }`.
  - `struct ReviewEntryStyle: Equatable` with `init(_ display: ReviewEntryDisplay)` and fields `timeRole`, `nameRole`, `bibRole`, `inOutRole: ReviewLabelRole`, `nameBold: Bool`.
  - `enum ReviewSyncButton { static func title(unsyncedCount: Int) -> String; static func isEnabled(unsyncedCount: Int, isSyncing: Bool) -> Bool }`.

- [ ] **Step 1: Write the failing tests**

Create `OST TrackerTests/Swift/ReviewPresentationTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class ReviewPresentationTests: XCTestCase {

    private func display(name: String? = "Jane Doe", bib: String? = "142",
                         bitKey: String? = "in", submitted: Bool = false,
                         pacer: String? = "0", stopped: String? = "0") -> ReviewEntryDisplay {
        ReviewEntryDisplay(displayTime: "7:42:10", fullName: name, bibNumber: bib,
                           bitKey: bitKey, submitted: submitted, withPacer: pacer, stoppedHere: stopped)
    }

    // Display mapping
    func test_display_resolvesName() {
        XCTAssertEqual(display(name: "Jane Doe").name, "Jane Doe")
        XCTAssertFalse(display(name: "Jane Doe").isBibMissing)
    }

    func test_display_emptyName_becomesBibNotFound() {
        let d = display(name: "")
        XCTAssertEqual(d.name, "Bib not found")
        XCTAssertTrue(d.isBibMissing)
    }

    func test_display_nilName_becomesBibNotFound() {
        XCTAssertTrue(display(name: nil).isBibMissing)
    }

    func test_display_bibFormatting() {
        XCTAssertEqual(display(bib: "142").bib, "#142")
    }

    func test_display_placeholderBib_isNil() {
        XCTAssertNil(display(bib: "-1").bib)
        XCTAssertNil(display(bib: nil).bib)
    }

    func test_display_inOutCapitalized() {
        XCTAssertEqual(display(bitKey: "in").inOut, "In")
        XCTAssertEqual(display(bitKey: "out").inOut, "Out")
    }

    func test_display_pacerAndStoppedTruthiness() {
        XCTAssertTrue(display(pacer: "1").showsPacer)
        XCTAssertFalse(display(pacer: "0").showsPacer)
        XCTAssertTrue(display(stopped: "true").showsStopped)
        XCTAssertFalse(display(stopped: nil).showsStopped)
    }

    // Style roles
    func test_style_syncedFound_allSuccess_notBold() {
        let s = ReviewEntryStyle(display(submitted: true))
        XCTAssertEqual(s.timeRole, .success)
        XCTAssertEqual(s.nameRole, .success)
        XCTAssertEqual(s.bibRole, .success)
        XCTAssertEqual(s.inOutRole, .success)
        XCTAssertFalse(s.nameBold)
    }

    func test_style_syncedMissing_successBold() {
        let s = ReviewEntryStyle(display(name: "", submitted: true))
        XCTAssertEqual(s.nameRole, .success)
        XCTAssertTrue(s.nameBold)
    }

    func test_style_unsyncedFound_normal_notBold() {
        let s = ReviewEntryStyle(display())
        XCTAssertEqual(s.timeRole, .normal)
        XCTAssertEqual(s.nameRole, .normal)
        XCTAssertEqual(s.bibRole, .secondary)
        XCTAssertEqual(s.inOutRole, .secondary)
        XCTAssertFalse(s.nameBold)
    }

    func test_style_unsyncedMissing_destructiveBold() {
        let s = ReviewEntryStyle(display(name: ""))
        XCTAssertEqual(s.nameRole, .destructive)
        XCTAssertTrue(s.nameBold)
    }

    // Sync button
    func test_syncTitle_zero_allSynced() {
        XCTAssertEqual(ReviewSyncButton.title(unsyncedCount: 0), "All Synced")
    }

    func test_syncTitle_one_singular() {
        XCTAssertEqual(ReviewSyncButton.title(unsyncedCount: 1), "Sync 1 Time")
    }

    func test_syncTitle_many_plural() {
        XCTAssertEqual(ReviewSyncButton.title(unsyncedCount: 12), "Sync 12 Times")
    }

    func test_syncEnabled_rules() {
        XCTAssertTrue(ReviewSyncButton.isEnabled(unsyncedCount: 3, isSyncing: false))
        XCTAssertFalse(ReviewSyncButton.isEnabled(unsyncedCount: 0, isSyncing: false))
        XCTAssertFalse(ReviewSyncButton.isEnabled(unsyncedCount: 3, isSyncing: true))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — compile error, `cannot find 'ReviewEntryDisplay' / 'ReviewEntryStyle' / 'ReviewSyncButton' in scope`.

> NOTE: New files must join the targets. Add `ReviewPresentation.swift` to the **OST Remote** + **OST Remote Dev** targets and `ReviewPresentationTests.swift` to **OST TrackerTests**, mirroring an existing sibling's entries in `OST Tracker.xcodeproj/project.pbxproj` (copy the `PBXBuildFile` + `PBXFileReference` + group `children` + `Sources` build-phase lines of, e.g., `MenuRow.swift` / `MenuRowTests.swift`, substituting fresh 24-hex UUIDs and the new paths). A new group `Review` may be added under the `Swift` group. Re-run after adding; a missing membership shows as "cannot find … in scope".

- [ ] **Step 3: Create `ReviewPresentation.swift`**

```swift
//  ReviewPresentation.swift
//  OST Tracker
//
//  Pure presentation logic for the Review/Sync list — no UIKit, no CoreData —
//  so the mapping/styling/title rules are unit-testable in isolation. Views and
//  the view controller consume these values.

import Foundation

/// Display values for one review row, derived from an entry's raw column strings.
struct ReviewEntryDisplay: Equatable {
    let time: String
    let name: String        // resolved; "Bib not found" when the bib has no name
    let bib: String?        // "#142", or nil for the "-1" placeholder / missing bib
    let inOut: String       // capitalized bitKey, e.g. "In" / "Out"
    let isSynced: Bool
    let isBibMissing: Bool
    let showsPacer: Bool
    let showsStopped: Bool

    /// Truthiness of the pacer/stopped flags follows `NSString.boolValue`
    /// (so "1" / "true" → true), matching the legacy CoreData string columns.
    init(displayTime: String?, fullName: String?, bibNumber: String?, bitKey: String?,
         submitted: Bool, withPacer: String?, stoppedHere: String?) {
        self.time = displayTime ?? ""
        let resolvedName = (fullName?.isEmpty ?? true) ? "Bib not found" : fullName!
        self.name = resolvedName
        self.isBibMissing = (resolvedName == "Bib not found")
        if let bibNumber = bibNumber, bibNumber != "-1" {
            self.bib = "#\(bibNumber)"
        } else {
            self.bib = nil
        }
        self.inOut = (bitKey ?? "").capitalized
        self.isSynced = submitted
        self.showsPacer = (withPacer as NSString?)?.boolValue ?? false
        self.showsStopped = (stoppedHere as NSString?)?.boolValue ?? false
    }
}

/// Semantic color role for a label — mapped to a `Theme` color by the view.
enum ReviewLabelRole { case normal, secondary, success, destructive }

/// The per-label styling for a row, as a pure function of its display values.
struct ReviewEntryStyle: Equatable {
    let timeRole: ReviewLabelRole
    let nameRole: ReviewLabelRole
    let bibRole: ReviewLabelRole
    let inOutRole: ReviewLabelRole
    let nameBold: Bool

    init(_ d: ReviewEntryDisplay) {
        if d.isSynced {
            timeRole = .success; nameRole = .success; bibRole = .success; inOutRole = .success
            nameBold = d.isBibMissing
        } else {
            timeRole = .normal; bibRole = .secondary; inOutRole = .secondary
            if d.isBibMissing {
                nameRole = .destructive; nameBold = true
            } else {
                nameRole = .normal; nameBold = false
            }
        }
    }
}

/// Bottom Sync button title + enabled state as a pure function of the unsynced
/// count and whether a sync is in flight.
enum ReviewSyncButton {
    static func title(unsyncedCount: Int) -> String {
        guard unsyncedCount > 0 else { return "All Synced" }
        return "Sync \(unsyncedCount) \(unsyncedCount == 1 ? "Time" : "Times")"
    }
    static func isEnabled(unsyncedCount: Int, isSyncing: Bool) -> Bool {
        unsyncedCount > 0 && !isSyncing
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS (all `ReviewPresentationTests` green).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/Review/ReviewPresentation.swift" "OST TrackerTests/Swift/ReviewPresentationTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(review): pure presentation logic for the Review/Sync list"
```

---

### Task 2: `ReviewEntryCell` + `ReviewSectionHeaderView` (design-system list views)

**Files:**
- Create: `OST Tracker/Swift/Review/ReviewListViews.swift`
- Test: `OST TrackerTests/Swift/ReviewEntryCellTests.swift`

**Interfaces:**
- Consumes: `ReviewEntryDisplay`, `ReviewEntryStyle`, `ReviewLabelRole` (Task 1); `Theme`.
- Produces:
  - `final class ReviewEntryCell: UITableViewCell` with `static let reuseID = "ReviewEntryCell"`, `func configure(with display: ReviewEntryDisplay)`, and test seams `nameText`, `timeText`, `bibText`, `inOutText: String?`, `appliedStyle: ReviewEntryStyle?`, `isPacerHidden`, `isStoppedHidden: Bool`.
  - `final class ReviewSectionHeaderView: UITableViewHeaderFooterView` with `static let reuseID = "ReviewSectionHeaderView"`, `func configure(title: String)`, and test seam `titleText: String?`.

- [ ] **Step 1: Write the failing tests**

Create `OST TrackerTests/Swift/ReviewEntryCellTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class ReviewEntryCellTests: XCTestCase {

    private func display(name: String? = "Jane Doe", bib: String? = "142",
                         submitted: Bool = false, pacer: String? = "0", stopped: String? = "0") -> ReviewEntryDisplay {
        ReviewEntryDisplay(displayTime: "7:42:10", fullName: name, bibNumber: bib,
                           bitKey: "in", submitted: submitted, withPacer: pacer, stoppedHere: stopped)
    }

    func test_configure_setsText() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display())
        XCTAssertEqual(cell.timeText, "7:42:10")
        XCTAssertEqual(cell.nameText, "Jane Doe")
        XCTAssertEqual(cell.bibText, "#142")
        XCTAssertEqual(cell.inOutText, "In")
    }

    func test_configure_placeholderBib_blankLabel() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(bib: "-1"))
        XCTAssertEqual(cell.bibText, "")
    }

    func test_configure_appliesStyle() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        let d = display(name: "", submitted: false) // unsynced + missing
        cell.configure(with: d)
        XCTAssertEqual(cell.appliedStyle, ReviewEntryStyle(d))
        XCTAssertEqual(cell.appliedStyle?.nameRole, .destructive)
    }

    func test_configure_iconVisibility() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(pacer: "1", stopped: "0"))
        XCTAssertFalse(cell.isPacerHidden)
        XCTAssertTrue(cell.isStoppedHidden)
    }

    func test_configure_reusedCell_updatesStyle() {
        let cell = ReviewEntryCell(style: .default, reuseIdentifier: nil)
        cell.configure(with: display(name: "", submitted: false))   // destructive
        cell.configure(with: display(name: "Jane Doe", submitted: true)) // success
        XCTAssertEqual(cell.appliedStyle?.nameRole, .success)
    }

    func test_header_setsTitle() {
        let header = ReviewSectionHeaderView(reuseIdentifier: nil)
        header.configure(title: "Start Entries:")
        XCTAssertEqual(header.titleText, "Start Entries:")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — `cannot find 'ReviewEntryCell' / 'ReviewSectionHeaderView' in scope`.

> NOTE: Add `ReviewListViews.swift` to **OST Remote** + **OST Remote Dev** and `ReviewEntryCellTests.swift` to **OST TrackerTests** in `project.pbxproj` (mirror as in Task 1).

- [ ] **Step 3: Create `ReviewListViews.swift`**

```swift
//  ReviewListViews.swift
//  OST Tracker
//
//  Design-system list views for the Review/Sync screen. Both consume the pure
//  presentation values from ReviewPresentation and map roles → Theme colors.

import UIKit

final class ReviewEntryCell: UITableViewCell {
    static let reuseID = "ReviewEntryCell"

    private let timeLabel = UILabel()
    private let nameLabel = UILabel()
    private let bibLabel = UILabel()
    private let inOutLabel = UILabel()
    private let pacerView = UIImageView()
    private let stoppedView = UIImageView()

    private(set) var appliedStyle: ReviewEntryStyle?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.secondaryBackground
        contentView.backgroundColor = Theme.secondaryBackground
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func buildUI() {
        timeLabel.font = Theme.Font.field
        bibLabel.font = Theme.Font.field
        inOutLabel.font = Theme.Font.field
        nameLabel.font = Theme.Font.field
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for v in [pacerView, stoppedView] {
            v.contentMode = .scaleAspectFit
            v.widthAnchor.constraint(equalToConstant: 22).isActive = true
            v.heightAnchor.constraint(equalToConstant: 22).isActive = true
        }
        let icons = UIStackView(arrangedSubviews: [pacerView, stoppedView])
        icons.spacing = 6

        let row = UIStackView(arrangedSubviews: [timeLabel, nameLabel, icons, bibLabel, inOutLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with display: ReviewEntryDisplay) {
        let style = ReviewEntryStyle(display)
        appliedStyle = style

        timeLabel.text = display.time
        nameLabel.text = display.name
        bibLabel.text = display.bib ?? ""
        inOutLabel.text = display.inOut

        timeLabel.textColor = color(for: style.timeRole)
        nameLabel.textColor = color(for: style.nameRole)
        bibLabel.textColor = color(for: style.bibRole)
        inOutLabel.textColor = color(for: style.inOutRole)
        nameLabel.font = style.nameBold ? .systemFont(ofSize: 17, weight: .bold) : Theme.Font.field

        pacerView.image = UIImage(named: display.isSynced ? "Pacer Symbol Green" : "Pacer Symbol Blue")
        stoppedView.image = UIImage(named: display.isSynced ? "Green Hand" : "Red Hand")
        pacerView.isHidden = !display.showsPacer
        stoppedView.isHidden = !display.showsStopped
    }

    private func color(for role: ReviewLabelRole) -> UIColor {
        switch role {
        case .normal:      return Theme.label
        case .secondary:   return Theme.secondaryLabel
        case .success:     return Theme.success
        case .destructive: return Theme.destructive
        }
    }

    // Test seams
    var nameText: String? { nameLabel.text }
    var timeText: String? { timeLabel.text }
    var bibText: String? { bibLabel.text }
    var inOutText: String? { inOutLabel.text }
    var isPacerHidden: Bool { pacerView.isHidden }
    var isStoppedHidden: Bool { stoppedView.isHidden }
}

final class ReviewSectionHeaderView: UITableViewHeaderFooterView {
    static let reuseID = "ReviewSectionHeaderView"

    private let titleLabel = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        titleLabel.font = Theme.Font.caption
        titleLabel.textColor = Theme.secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(title: String) { titleLabel.text = title }

    // Test seam
    var titleText: String? { titleLabel.text }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS (all `ReviewEntryCellTests` green).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/Review/ReviewListViews.swift" "OST TrackerTests/Swift/ReviewEntryCellTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(review): design-system entry cell + section header"
```

---

### Task 3: Rewrite `OSTReviewSubmitViewController` programmatically

**Files:**
- Modify (full rewrite): `OST Tracker/ViewControllers/OSTReviewSubmitViewController.swift`

**Interfaces:**
- Consumes: `ReviewEntryDisplay`, `ReviewEntryCell`, `ReviewSectionHeaderView`, `ReviewSyncButton` (Tasks 1–2); `Theme`, `PrimaryButton`, `BottomSheetPicker.present(from:title:options:selected:onSelect:)`, `OSTToast`; existing `AutoSyncController.shared` (`isSyncing`, `syncEntries(_:)`, `isSyncingEntry(_:)`, `showToastOnCompletion`); base `OSTBaseViewController` (`menuButton`, `badgeLabel`, `updateSyncBadge`); `EntryModel`, `CurrentCourse`, `OSTEditEntryViewController`, `AppDelegate`.
- Produces: the same `@objc(OSTReviewSubmitViewController)` instantiated by `AppDelegate.showReview()` via `initWithNibName:nil bundle:nil` (now builds its view in code instead of loading the deleted XIB).

> NOTE: This file is already in both targets — no pbxproj change. `showReview` already calls `initWithNibName:nil bundle:nil`; with the XIB gone (Task 4), UIKit creates a plain view and `viewDidLoad` builds the UI. The XIB deletion happens in Task 4 so this task stays build-green on its own (the XIB simply goes unused once the outlets are removed).

- [ ] **Step 1: Replace the file**

Overwrite `OST Tracker/ViewControllers/OSTReviewSubmitViewController.swift` with:

```swift
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
    private let badge = UILabel()
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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()

        // Hand the base VC its badge + menu button so updateSyncBadge keeps working.
        menuButton = menuBtn
        badgeLabel = badge

        if let stored = UserDefaults.standard.object(forKey: "reviewScreenPicklistValue") as? NSNumber {
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

        menuBtn.setTitle("\u{2630}", for: .normal) // ☰
        menuBtn.setTitleColor(Theme.label, for: .normal)
        menuBtn.titleLabel?.font = .systemFont(ofSize: 24)
        menuBtn.addTarget(self, action: #selector(onRightMenu), for: .touchUpInside)
        menuBtn.widthAnchor.constraint(equalToConstant: 34).isActive = true

        exportButton.setTitle("Export", for: .normal)
        exportButton.setTitleColor(Theme.tint, for: .normal)
        exportButton.titleLabel?.font = Theme.Font.button
        exportButton.addTarget(self, action: #selector(onExport(_:)), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [menuBtn, titleLabel, exportButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12

        // Count badge pinned to the menu button's top-trailing corner.
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = Theme.destructive
        badge.textAlignment = .center
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badge)

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

            badge.topAnchor.constraint(equalTo: menuBtn.topAnchor, constant: -4),
            badge.leadingAnchor.constraint(equalTo: menuBtn.trailingAnchor, constant: -14),
            badge.heightAnchor.constraint(equalToConstant: 18),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
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
        switch sortSelection {
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

        titleLabel.text = course.eventName
        tableView.reloadData()
        updateSyncButtonState()
    }

    private func unsyncedCount() -> Int {
        guard let courseId = CurrentCourse.getCurrentCourse()?.eventId else { return 0 }
        let toSubmit = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@ && submitted == NIL && bibNumber != %@", courseId, "-1")) as? [EntryModel]) ?? []
        return toSubmit.count
    }

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
        super.updateSyncBadge()
        badge.isHidden = !shouldShowBadge
        badge.text = self.badge.isHidden ? nil : (badge.text)
        // super sets badgeLabel.text + hidden + shape; nothing else needed here.
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
            let error1 = nsErrors[0]
            let message1 = error1.code == -1009 ? "The device is not connected" : "Error: \(error1.errorsFromDictionary() ?? "")"
            let error2 = nsErrors[1]
            let message2 = "Error: \(error2.errorsFromDictionary() ?? "")"
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
            UserDefaults.standard.set(idx, forKey: "reviewScreenPicklistValue")
            UserDefaults.standard.synchronize()
            self.updateSortButtonTitle()
            self.loadData()
        }
    }

    @objc func onRightMenu(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    // Parameterless overload so the menu button's selector matches.
    @objc func onRightMenu() { onRightMenu(self) }

    @objc func onSubmit(_ sender: Any) {
        UIDevice.current.playInputClick()
        guard let courseId = CurrentCourse.getCurrentCourse()?.eventId else { return }

        let toSubmit = (EntryModel.mr_findAll(with: NSPredicate(format: "combinedCourseId == %@ && submitted == NIL && bibNumber != %@", courseId, "-1")) as? [EntryModel]) ?? []
        if toSubmit.isEmpty {
            ostPresentAlert(title: "", message: entries.isEmpty ? "No times have been entered." : "All times have been synced.")
            return
        }

        progressBar.setProgress(0, animated: false)
        AutoSyncController.shared.syncEntries(toSubmit)
        updateSyncButtonState()
    }

    @objc func onExport(_ sender: Any) {
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
```

> NOTE on the badge override: `super.updateSyncBadge()` (Obj-C base) computes the unsynced count and sets `badgeLabel.text` / `.hidden` / shape on our `badge` label. The two lines after `super` are belt-and-suspenders for the hidden state; if the compiler objects to `self.badge.isHidden` shadowing, simplify the override body to just `super.updateSyncBadge()` — the base already drives the label. Confirm against the real base behavior during Step 2.

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

> If the build fails on the `updateSyncBadge` override body, replace it with just `super.updateSyncBadge()` (the base sets `badgeLabel.text`/`.hidden`/shape on our `badge`). If it fails on `menuButton`/`badgeLabel` assignment, confirm they are the base's `@property` outlets (they are: `OSTBaseViewController.h`) — assign them after `buildUI()`.

- [ ] **Step 3: Run the test suite to confirm nothing regressed**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS (Tasks 1–2 tests + existing suite green).

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTReviewSubmitViewController.swift"
git commit -m "feat(review): programmatic DesignSystem rewrite of Review/Sync"
```

- [ ] **Step 5: Manual verification (hand to user)**

Open Review/Sync and confirm: event name in the header; the count badge sits over the ☰ menu button; **Export** opens the "local device only" alert → share sheet (iPad popover anchored). The **Sort** row opens the bottom-sheet picker; choosing an option re-sorts and the choice persists across visits. The list is grouped by split with "<Split> Entries:" headers; synced rows are green, unsynced "Bib not found" rows are red+bold. Tapping the full-width **Sync N Times** button shows the inline progress bar + "Syncing…", cells turn green, and a success **toast** appears on completion (no full-screen overlay); the button settles to "All Synced" / disabled. Force a sync error → "Unable to sync" alert. On a notched device the Sync button clears the home indicator and the last rows scroll clear above it. Edit/replacement flows still work.

---

### Task 4: Delete the legacy XIB + Obj-C cell/header files

**Files:**
- Delete: `OST Tracker/ViewControllers/OSTReviewSubmitViewController.xib`
- Delete: `OST Tracker/ViewControllers/TableViewCells/OSTReviewTableViewCell.{h,m,xib}`
- Delete: `OST Tracker/ViewControllers/OSTReviewSectionHeader.{h,m,xib}`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (remove all references to the deleted files)
- Modify (if present): `OST Tracker/OST Tracker-Bridging-Header.h` (remove imports of the deleted headers)

**Interfaces:**
- Consumes: nothing. Pure removal; Task 3 replaced the only users (`OSTReviewTableViewCell`, `OSTReviewSectionHeader`, and the XIB) with the new Swift views.
- Produces: nothing.

- [ ] **Step 1: Confirm nothing else references the deleted symbols**

Run:
```bash
grep -rn "OSTReviewTableViewCell\|OSTReviewSectionHeader" "OST Tracker" --include=*.swift --include=*.m --include=*.h | grep -v "OSTReviewSubmitViewController.swift"
```
Expected: no output (Task 3's rewrite no longer references them). If anything matches, stop and resolve before deleting.

- [ ] **Step 2: Delete the files**

```bash
git rm "OST Tracker/ViewControllers/OSTReviewSubmitViewController.xib" \
       "OST Tracker/ViewControllers/TableViewCells/OSTReviewTableViewCell.h" \
       "OST Tracker/ViewControllers/TableViewCells/OSTReviewTableViewCell.m" \
       "OST Tracker/ViewControllers/TableViewCells/OSTReviewTableViewCell.xib" \
       "OST Tracker/ViewControllers/OSTReviewSectionHeader.h" \
       "OST Tracker/ViewControllers/OSTReviewSectionHeader.m" \
       "OST Tracker/ViewControllers/OSTReviewSectionHeader.xib"
```

- [ ] **Step 3: Remove the project references + bridging-header imports**

In `OST Tracker.xcodeproj/project.pbxproj`, remove every line mentioning `OSTReviewSubmitViewController.xib`, `OSTReviewTableViewCell`, or `OSTReviewSectionHeader` — these come in matched sets across both targets: `PBXBuildFile` (`.m in Sources`, `.xib in Resources`), `PBXFileReference`, group `children`, and `Sources`/`Resources` build-phase entries. Then, if `OST Tracker/OST Tracker-Bridging-Header.h` imports `OSTReviewTableViewCell.h` or `OSTReviewSectionHeader.h`, delete those `#import` lines. Verify:
```bash
grep -n "OSTReviewTableViewCell\|OSTReviewSectionHeader\|OSTReviewSubmitViewController.xib" "OST Tracker.xcodeproj/project.pbxproj" "OST Tracker/OST Tracker-Bridging-Header.h"
```
Expected: no output.

- [ ] **Step 4: Build + test to verify the project is still valid**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: BUILD SUCCEEDED and all tests PASS. (A broken pbxproj edit usually fails with "Build input file cannot be found" or a project-parse error — if so, restore the file refs you removed in matched sets.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(review): remove legacy Review/Sync XIB + Obj-C cell/header"
```

---

## Self-Review

**Spec coverage:**
- §1 full rewrite to DesignSystem; retire XIB/cells/header/frame-hacks → Task 3 (rewrite) + Task 4 (deletions). ✓
- §2 header (event name, text Export button, sort row → BottomSheetPicker), grouped list, pinned full-width Sync bar, no frame math → Task 3. ✓
- §3 ReviewEntryCell data + synced/missing coloring + pacer/stopped assets → Task 1 (style rules) + Task 2 (cell) + Task 3 (`ReviewEntryDisplay(entry:)`). ✓
- §4 inline progress + OSTToast, overlay retired, Sync label w/ count → Task 1 (`ReviewSyncButton`) + Task 3 (`updateSyncButtonState`, delegate overrides, `showToastOnCompletion`). ✓
- §5 Export as header button → unchanged `onExport`/`exportCSV` in Task 3. ✓
- §6 error/empty/edit alerts preserved → Task 3 (`didFinishWithErrors`, `onSubmit`/`onExport` empty checks, `didSelectRowAt`). ✓
- §7 testing: pure logic unit-tested (Tasks 1–2), build+manual for UIKit glue (Tasks 3–4). ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. The Task 3 badge-override and target-membership NOTEs give exact fallbacks, not deferrals. ✓

**Type consistency:** `ReviewEntryDisplay` / `ReviewEntryStyle` / `ReviewLabelRole` / `ReviewSyncButton.title(unsyncedCount:)` / `isEnabled(unsyncedCount:isSyncing:)` (Task 1) are consumed with identical signatures in Tasks 2–3. `ReviewEntryCell.reuseID` / `configure(with:)` and `ReviewSectionHeaderView.reuseID` / `configure(title:)` (Task 2) match their use in Task 3's table data source. Preserved predicates/keys/selectors match the originals verbatim. ✓
