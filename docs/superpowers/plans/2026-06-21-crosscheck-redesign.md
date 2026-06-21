# Cross Check Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Cross Check aid-station screen in the new design system, reshaped around spotting who hasn't arrived yet (Expected / "still out"), and drop bulk-select.

**Architecture:** Pure presentation logic (`CrossCheckPresentation`, no UIKit/CoreData) maps efforts → a `CrossCheckBoard` of status buckets, mirroring `ReviewPresentation`. Programmatic `Theme`-based views render an Expected list + three summary rows; tapping a bib opens a themed bottom sheet, tapping a summary row pushes a drill-in list. The view controller keeps its `@objc` name and all CoreData operations, retiring the storyboard + Obj-C cell/header/footer.

**Tech Stack:** Swift (iOS 12 floor, completion handlers — no async/await), UIKit programmatic (no storyboard/XIB), XCTest, the existing `Theme`/DesignSystem, MagicalRecord shim for CoreData.

## Global Constraints

- iOS 12 compatible: no async/await, no SF Symbols, no APIs newer than iOS 12 without `#available` guards. (Floor: iPad mini 2/3.)
- All colors via `Theme` roles — never hardcode `UIColor` literals in views.
- Programmatic UI only (no new storyboard/XIB), matching `OSTReviewSubmitViewController`.
- Pure presentation/business logic lives in non-UIKit files and is unit-tested; CoreData types never cross into the pure layer.
- DRY / YAGNI. Frequent commits (one per task).
- Test module import is `@testable import OST_Remote`. Tests live under `OST TrackerTests/Swift/`.
- Build/test command (iPad sim):
  ```
  xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
    -destination 'platform=iOS Simulator,name=iPad (9th generation)' \
    -only-testing:"OST TrackerTests/<TestClass>" 2>&1 | tail -25
  ```
  Full build only:
  ```
  xcodebuild build -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
    -destination 'platform=iOS Simulator,name=iPad (9th generation)' 2>&1 | tail -25
  ```
- Visual/interaction verification is handed to the human (do not drive the simulator).

---

### Task 1: Add `Theme.warning` color role

**Files:**
- Modify: `OST Tracker/Swift/DesignSystem/Theme.swift`
- Test: `OST TrackerTests/Swift/ThemeTests.swift`

**Interfaces:**
- Produces: `Theme.warning` (a dynamic `UIColor`), `Palette.lightWarning`, `Palette.darkWarning`.

- [ ] **Step 1: Write the failing test**

Add to `ThemeTests.swift`:

```swift
func testWarningRoleResolvesToSystemOrange() {
    let light = Theme.resolved(Theme.warning, dark: false)
    XCTAssertEqual(light, Palette.lightWarning)
}
```

If `ThemeTests` has no `resolved` helper, instead assert the palette values directly:

```swift
func testWarningPaletteIsOrange() {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    Palette.lightWarning.getRed(&r, green: &g, blue: &b, alpha: &a)
    XCTAssertEqual(r, 1.0, accuracy: 0.01)   // systemOrange ≈ (255,149,0)
    XCTAssertEqual(g, 149.0/255, accuracy: 0.01)
    XCTAssertEqual(b, 0.0, accuracy: 0.01)
}
```

- [ ] **Step 2: Run test, verify it fails**

Run the test command with `-only-testing:"OST TrackerTests/ThemeTests"`.
Expected: FAIL — `Palette.lightWarning` undefined.

- [ ] **Step 3: Implement**

In `Theme.swift`, add the role next to `destructive`:

```swift
static var warning: UIColor { dynamic(light: Palette.lightWarning, dark: Palette.darkWarning) }
```

And in `Palette`, next to the destructive values:

```swift
static let lightWarning             = UIColor(red: 255/255, green: 149/255, blue: 0/255,  alpha: 1) // systemOrange
static let darkWarning              = UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 1)
```

- [ ] **Step 4: Run test, verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/Theme.swift" "OST TrackerTests/Swift/ThemeTests.swift"
git commit -m "feat(theme): add warning (orange) color role"
```

---

### Task 2: `CrossCheckPresentation` — pure model + builder

**Files:**
- Create: `OST Tracker/Swift/CrossCheck/CrossCheckPresentation.swift`
- Test: `OST TrackerTests/Swift/CrossCheckPresentationTests.swift`

**Interfaces:**
- Consumes: nothing (pure Foundation).
- Produces:
  - `enum CrossCheckStatus { case expected, recorded, droppedHere, notExpected }`
  - `struct EffortFacts { let bib: String; let name: String; let hasEntries: Bool; let isStopped: Bool; let isExpected: Bool; let time: String? }`
  - `struct CrossCheckRow: Equatable { let bib: String; let name: String; let status: CrossCheckStatus; let time: String? }`
  - `struct CrossCheckBoard: Equatable { let expected, recorded, droppedHere, notExpected: [CrossCheckRow] }` with `var expectedCount/recordedCount/droppedHereCount/notExpectedCount: Int`.
  - `static func CrossCheckPresentation.status(for facts: EffortFacts) -> CrossCheckStatus`
  - `static func CrossCheckPresentation.build(from facts: [EffortFacts]) -> CrossCheckBoard`
  - `struct CrossCheckSheetConfig: Equatable { let bib: String; let name: String; let showsExpectedToggle: Bool; let isExpected: Bool }`
  - `static func CrossCheckPresentation.sheetConfig(for row: CrossCheckRow) -> CrossCheckSheetConfig`

- [ ] **Step 1: Write the failing tests**

Create `CrossCheckPresentationTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class CrossCheckPresentationTests: XCTestCase {

    private func facts(bib: String, name: String = "Runner",
                       hasEntries: Bool = false, isStopped: Bool = false,
                       isExpected: Bool = true, time: String? = nil) -> EffortFacts {
        EffortFacts(bib: bib, name: name, hasEntries: hasEntries,
                    isStopped: isStopped, isExpected: isExpected, time: time)
    }

    func testStatusDerivation() {
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "1", hasEntries: true, isStopped: false)), .recorded)
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "2", hasEntries: true, isStopped: true)), .droppedHere)
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "3", hasEntries: false, isExpected: true)), .expected)
        XCTAssertEqual(CrossCheckPresentation.status(for: facts(bib: "4", hasEntries: false, isExpected: false)), .notExpected)
    }

    func testBuildBucketsAndCounts() {
        let board = CrossCheckPresentation.build(from: [
            facts(bib: "1", hasEntries: true),
            facts(bib: "2", hasEntries: true, isStopped: true),
            facts(bib: "3", isExpected: true),
            facts(bib: "4", isExpected: true),
            facts(bib: "5", isExpected: false),
        ])
        XCTAssertEqual(board.expectedCount, 2)
        XCTAssertEqual(board.recordedCount, 1)
        XCTAssertEqual(board.droppedHereCount, 1)
        XCTAssertEqual(board.notExpectedCount, 1)
        XCTAssertEqual(board.expected.map { $0.bib }, ["3", "4"])
    }

    func testBuildExcludesEmptyBib() {
        let board = CrossCheckPresentation.build(from: [
            facts(bib: "", isExpected: true),
            facts(bib: "7", isExpected: true),
        ])
        XCTAssertEqual(board.expected.map { $0.bib }, ["7"])
    }

    func testSheetConfigShowsToggleOnlyWhenNotRecorded() {
        let expectedRow = CrossCheckRow(bib: "3", name: "A", status: .expected, time: nil)
        let recordedRow = CrossCheckRow(bib: "1", name: "B", status: .recorded, time: "10:42")
        XCTAssertEqual(CrossCheckPresentation.sheetConfig(for: expectedRow),
                       CrossCheckSheetConfig(bib: "3", name: "A", showsExpectedToggle: true, isExpected: true))
        XCTAssertEqual(CrossCheckPresentation.sheetConfig(for: recordedRow),
                       CrossCheckSheetConfig(bib: "1", name: "B", showsExpectedToggle: false, isExpected: false))
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

`-only-testing:"OST TrackerTests/CrossCheckPresentationTests"`.
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement**

Create `CrossCheckPresentation.swift`:

```swift
//  CrossCheckPresentation.swift
//  OST Tracker
//
//  Pure presentation logic for the Cross Check board — no UIKit, no CoreData —
//  so status bucketing and sheet rules are unit-testable in isolation. The view
//  controller adapts EffortModel into EffortFacts and renders the result.

import Foundation

enum CrossCheckStatus { case expected, recorded, droppedHere, notExpected }

/// Plain facts about one effort at the current split, derived by the VC from
/// EffortModel (so CoreData never crosses into this pure layer).
struct EffortFacts {
    let bib: String
    let name: String
    let hasEntries: Bool
    let isStopped: Bool
    let isExpected: Bool   // expected(withSplitName:) was nil or true
    let time: String?
}

struct CrossCheckRow: Equatable {
    let bib: String
    let name: String
    let status: CrossCheckStatus
    let time: String?
}

struct CrossCheckBoard: Equatable {
    let expected: [CrossCheckRow]
    let recorded: [CrossCheckRow]
    let droppedHere: [CrossCheckRow]
    let notExpected: [CrossCheckRow]

    var expectedCount: Int { expected.count }
    var recordedCount: Int { recorded.count }
    var droppedHereCount: Int { droppedHere.count }
    var notExpectedCount: Int { notExpected.count }
}

struct CrossCheckSheetConfig: Equatable {
    let bib: String
    let name: String
    let showsExpectedToggle: Bool
    let isExpected: Bool
}

enum CrossCheckPresentation {

    static func status(for facts: EffortFacts) -> CrossCheckStatus {
        if facts.hasEntries {
            return facts.isStopped ? .droppedHere : .recorded
        }
        return facts.isExpected ? .expected : .notExpected
    }

    /// Buckets efforts by status. Empty bibs are dropped (roster efforts always
    /// have a bib; this just guards a nil bibNumber that stringified to "").
    /// (The legacy effort-side "-1" filter was removed upstream in e0feae1 as
    /// obsolete — roster efforts never carry the "-1" entry placeholder.)
    static func build(from facts: [EffortFacts]) -> CrossCheckBoard {
        var expected: [CrossCheckRow] = []
        var recorded: [CrossCheckRow] = []
        var dropped: [CrossCheckRow] = []
        var notExpected: [CrossCheckRow] = []

        for f in facts {
            guard !f.bib.isEmpty else { continue }
            let s = status(for: f)
            let row = CrossCheckRow(bib: f.bib, name: f.name, status: s, time: f.time)
            switch s {
            case .expected:     expected.append(row)
            case .recorded:     recorded.append(row)
            case .droppedHere:  dropped.append(row)
            case .notExpected:  notExpected.append(row)
            }
        }
        return CrossCheckBoard(expected: expected, recorded: recorded,
                               droppedHere: dropped, notExpected: notExpected)
    }

    /// The action sheet shows the Expected/Not-expected toggle only for runners
    /// that have not been recorded yet (expected or not-expected status).
    static func sheetConfig(for row: CrossCheckRow) -> CrossCheckSheetConfig {
        let togglable = (row.status == .expected || row.status == .notExpected)
        return CrossCheckSheetConfig(bib: row.bib, name: row.name,
                                     showsExpectedToggle: togglable,
                                     isExpected: row.status == .expected)
    }
}
```

- [ ] **Step 4: Add the new file to the Xcode target**

The file must compile into both `OST Remote` and (for `@testable`) be visible to tests. Add it to the `OST Remote` target's Compile Sources in `OST Tracker.xcodeproj/project.pbxproj` (it appears in `OST_Remote` via `@testable`, no separate test-target membership needed). Use the same approach the repo already uses for other `Swift/` files: add a `PBXFileReference`, a `PBXBuildFile`, the group entry under the new `CrossCheck` group, and the `Sources` build-phase entry. Verify by building.

- [ ] **Step 5: Run tests, verify they pass**

Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/Swift/CrossCheck/CrossCheckPresentation.swift" \
        "OST TrackerTests/Swift/CrossCheckPresentationTests.swift" \
        "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(crosscheck): pure presentation model + status bucketing"
```

---

### Task 3: `CrossCheckListViews` — themed rows + header

**Files:**
- Create: `OST Tracker/Swift/CrossCheck/CrossCheckListViews.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (add file to target)
- Test: `OST TrackerTests/Swift/CrossCheckListViewsTests.swift`

**Interfaces:**
- Consumes: `CrossCheckRow`, `CrossCheckStatus`, `Theme`.
- Produces:
  - `final class CrossCheckExpectedCell: UITableViewCell` — `static let reuseID`, `func configure(with row: CrossCheckRow)`, test seams `bibText`, `nameText`.
  - `final class CrossCheckSummaryCell: UITableViewCell` — `static let reuseID`, `func configure(status: CrossCheckStatus, title: String, count: Int)`, test seams `titleText`, `countText`, `dotColor`.
  - `static func CrossCheckStatus.dotColor` → `UIColor` mapping (expected→`Theme.warning`, recorded→`Theme.success`, droppedHere→`Theme.destructive`, notExpected→`Theme.secondaryLabel`).

- [ ] **Step 1: Write the failing test**

Create `CrossCheckListViewsTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class CrossCheckListViewsTests: XCTestCase {
    func testExpectedCellShowsBibAndName() {
        let cell = CrossCheckExpectedCell(style: .default, reuseIdentifier: CrossCheckExpectedCell.reuseID)
        cell.configure(with: CrossCheckRow(bib: "214", name: "Dean Karnazes", status: .expected, time: nil))
        XCTAssertEqual(cell.bibText, "214")
        XCTAssertEqual(cell.nameText, "Dean Karnazes")
    }

    func testSummaryCellShowsTitleAndCount() {
        let cell = CrossCheckSummaryCell(style: .default, reuseIdentifier: CrossCheckSummaryCell.reuseID)
        cell.configure(status: .recorded, title: "Recorded", count: 61)
        XCTAssertEqual(cell.titleText, "Recorded")
        XCTAssertEqual(cell.countText, "61")
        XCTAssertEqual(cell.dotColor, CrossCheckStatus.recorded.dotColor)
    }
}
```

- [ ] **Step 2: Run, verify fail** — types undefined.

- [ ] **Step 3: Implement**

Create `CrossCheckListViews.swift`. Follow `ReviewListViews.swift` construction style (programmatic stack, `Theme` colors):

```swift
//  CrossCheckListViews.swift
//  OST Tracker
//
//  Design-system list cells for the Cross Check board. Colors map through Theme.

import UIKit

extension CrossCheckStatus {
    var dotColor: UIColor {
        switch self {
        case .expected:    return Theme.warning
        case .recorded:    return Theme.success
        case .droppedHere: return Theme.destructive
        case .notExpected: return Theme.secondaryLabel
        }
    }
}

/// A "still out" row: large bib + full name + chevron.
final class CrossCheckExpectedCell: UITableViewCell {
    static let reuseID = "CrossCheckExpectedCell"

    private let bibLabel = UILabel()
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.secondaryBackground
        contentView.backgroundColor = Theme.secondaryBackground
        accessoryType = .disclosureIndicator
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func buildUI() {
        bibLabel.font = .systemFont(ofSize: 22, weight: .bold)
        bibLabel.textColor = Theme.label
        bibLabel.setContentHuggingPriority(.required, for: .horizontal)
        bibLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        nameLabel.font = Theme.Font.field
        nameLabel.textColor = Theme.label

        let row = UIStackView(arrangedSubviews: [bibLabel, nameLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with row: CrossCheckRow) {
        bibLabel.text = row.bib
        nameLabel.text = row.name
    }

    var bibText: String? { bibLabel.text }
    var nameText: String? { nameLabel.text }
}

/// A compact summary row: status dot + title + count + chevron.
final class CrossCheckSummaryCell: UITableViewCell {
    static let reuseID = "CrossCheckSummaryCell"

    private let dot = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.secondaryBackground
        contentView.backgroundColor = Theme.secondaryBackground
        accessoryType = .disclosureIndicator
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func buildUI() {
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        titleLabel.font = Theme.Font.field
        titleLabel.textColor = Theme.label

        countLabel.font = Theme.Font.field
        countLabel.textColor = Theme.secondaryLabel

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [dot, titleLabel, spacer, countLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }

    func configure(status: CrossCheckStatus, title: String, count: Int) {
        dot.backgroundColor = status.dotColor
        titleLabel.text = title
        countLabel.text = "\(count)"
    }

    var titleText: String? { titleLabel.text }
    var countText: String? { countLabel.text }
    var dotColor: UIColor? { dot.backgroundColor }
}
```

- [ ] **Step 4: Add file to target** (same pbxproj approach as Task 2, Step 4).

- [ ] **Step 5: Run tests, verify pass** — `-only-testing:"OST TrackerTests/CrossCheckListViewsTests"`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/Swift/CrossCheck/CrossCheckListViews.swift" \
        "OST TrackerTests/Swift/CrossCheckListViewsTests.swift" \
        "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(crosscheck): themed expected + summary list cells"
```

---

### Task 4: `CrossCheckActionSheet` — per-bib bottom sheet

**Files:**
- Create: `OST Tracker/Swift/CrossCheck/CrossCheckActionSheet.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `CrossCheckSheetConfig`, `Theme`, `PrimaryButton`.
- Produces:
  - `final class CrossCheckActionSheet: UIViewController`
  - `static func present(from presenter: UIViewController, config: CrossCheckSheetConfig, onSetExpected: @escaping (Bool) -> Void, onReviewEntries: @escaping () -> Void)`
  - When `showsExpectedToggle` is false, the segmented control is hidden and only "Review entries" shows. Closing the sheet after a toggle change calls `onSetExpected(newValue)`; "Review entries" calls `onReviewEntries()`.

- [ ] **Step 1: Implement** (no unit test — the togglable logic is already tested via `sheetConfig`; this is presentation glue verified by build + human check)

Create `CrossCheckActionSheet.swift`:

```swift
//  CrossCheckActionSheet.swift
//  OST Tracker
//
//  Themed bottom sheet for one bib: shows bib + name, an Expected/Not-expected
//  segmented control (only for not-yet-recorded runners), and Review entries.
//  Replaces the legacy bulk-select popup with a single-bib action.

import UIKit

final class CrossCheckActionSheet: UIViewController {

    private let config: CrossCheckSheetConfig
    private let onSetExpected: (Bool) -> Void
    private let onReviewEntries: () -> Void

    private let segmented = UISegmentedControl(items: ["Expected", "Not expected"])

    private init(config: CrossCheckSheetConfig,
                 onSetExpected: @escaping (Bool) -> Void,
                 onReviewEntries: @escaping () -> Void) {
        self.config = config
        self.onSetExpected = onSetExpected
        self.onReviewEntries = onReviewEntries
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    static func present(from presenter: UIViewController,
                        config: CrossCheckSheetConfig,
                        onSetExpected: @escaping (Bool) -> Void,
                        onReviewEntries: @escaping () -> Void) {
        let sheet = CrossCheckActionSheet(config: config,
                                          onSetExpected: onSetExpected,
                                          onReviewEntries: onReviewEntries)
        presenter.present(sheet, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)

        let dimTap = UITapGestureRecognizer(target: self, action: #selector(onDismiss))
        view.addGestureRecognizer(dimTap)

        let card = UIView()
        card.backgroundColor = Theme.secondaryBackground
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false
        // Swallow taps so tapping inside the card doesn't dismiss.
        card.addGestureRecognizer(UITapGestureRecognizer(target: nil, action: nil))
        view.addSubview(card)

        let grabber = UIView()
        grabber.backgroundColor = Theme.separator
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.widthAnchor.constraint(equalToConstant: 36).isActive = true
        grabber.heightAnchor.constraint(equalToConstant: 5).isActive = true

        let bibLabel = UILabel()
        bibLabel.text = config.bib
        bibLabel.font = .systemFont(ofSize: 34, weight: .bold)
        bibLabel.textColor = Theme.label
        bibLabel.textAlignment = .center

        let nameLabel = UILabel()
        nameLabel.text = config.name
        nameLabel.font = Theme.Font.field
        nameLabel.textColor = Theme.secondaryLabel
        nameLabel.textAlignment = .center

        segmented.selectedSegmentIndex = config.isExpected ? 0 : 1
        segmented.isHidden = !config.showsExpectedToggle
        segmented.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)

        let reviewButton = PrimaryButton(title: "Review entries", role: .primary)
        reviewButton.addTarget(self, action: #selector(onReviewTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [grabber, bibLabel, nameLabel, segmented, reviewButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(2, after: bibLabel)
        stack.setCustomSpacing(20, after: nameLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Center the grabber within the fill stack.
        grabber.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubview(stack)

        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 18),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        // Keep the grabber centered.
        grabber.centerXAnchor.constraint(equalTo: card.centerXAnchor).isActive = true
    }

    @objc private func onSegmentChanged() {
        onSetExpected(segmented.selectedSegmentIndex == 0)
    }

    @objc private func onReviewTapped() {
        dismiss(animated: true) { [weak self] in self?.onReviewEntries() }
    }

    @objc private func onDismiss() {
        dismiss(animated: true)
    }
}
```

> Note: `onSetExpected` fires immediately on toggle (the VC persists + reloads). This is simpler and more reliable than deferring to dismiss, and matches "set status, see it move out of Expected."

- [ ] **Step 2: Add file to target** (pbxproj).

- [ ] **Step 3: Build, verify it compiles**

Run the full build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/Swift/CrossCheck/CrossCheckActionSheet.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(crosscheck): per-bib action sheet"
```

---

### Task 5: `CrossCheckGroupViewController` — drill-in list

**Files:**
- Create: `OST Tracker/Swift/CrossCheck/CrossCheckGroupViewController.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `CrossCheckRow`, `CrossCheckExpectedCell`, `Theme`, `OSTBaseViewController`, `CrossCheckActionSheet`, `CrossCheckPresentation.sheetConfig`.
- Produces:
  - `final class CrossCheckGroupViewController: OSTBaseViewController` with `init(title: String, rows: [CrossCheckRow], onSetExpected: @escaping (CrossCheckRow, Bool) -> Void, onReviewEntries: @escaping () -> Void)`.
  - Presented modally (its own nav-less screen) or pushed; here it is presented modally with a Close button (no UINavigationController is in play — the app uses a drawer center VC). Tapping a row opens the action sheet.

- [ ] **Step 1: Implement**

Create `CrossCheckGroupViewController.swift`:

```swift
//  CrossCheckGroupViewController.swift
//  OST Tracker
//
//  A drill-in list of bibs for one Cross Check status group (Recorded / Dropped
//  here / Not expected). Reuses the expected cell style; tapping a row opens the
//  per-bib action sheet.

import UIKit

final class CrossCheckGroupViewController: OSTBaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let groupTitle: String
    private var rows: [CrossCheckRow]
    private let onSetExpected: (CrossCheckRow, Bool) -> Void
    private let onReviewEntries: () -> Void

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(title: String, rows: [CrossCheckRow],
         onSetExpected: @escaping (CrossCheckRow, Bool) -> Void,
         onReviewEntries: @escaping () -> Void) {
        self.groupTitle = title
        self.rows = rows
        self.onSetExpected = onSetExpected
        self.onReviewEntries = onReviewEntries
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        titleLabel.text = "\(groupTitle) · \(rows.count)"
        titleLabel.font = Theme.Font.brand
        titleLabel.textColor = Theme.label

        closeButton.setTitle("Done", for: .normal)
        closeButton.setTitleColor(Theme.tint, for: .normal)
        closeButton.titleLabel?.font = Theme.Font.button
        closeButton.addTarget(self, action: #selector(onClose), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), closeButton])
        header.axis = .horizontal
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(CrossCheckExpectedCell.self, forCellReuseIdentifier: CrossCheckExpectedCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(tableView)
        let guide = view.safeAreaLayoutGuide
        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            header.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    @objc private func onClose() { dismiss(animated: true) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CrossCheckExpectedCell.reuseID, for: indexPath) as! CrossCheckExpectedCell
        cell.configure(with: rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        CrossCheckActionSheet.present(from: self,
                                      config: CrossCheckPresentation.sheetConfig(for: row),
                                      onSetExpected: { [weak self] expected in self?.onSetExpected(row, expected) },
                                      onReviewEntries: { [weak self] in self?.onReviewEntries() })
    }
}
```

- [ ] **Step 2: Add file to target** (pbxproj).
- [ ] **Step 3: Build, verify compiles.** Expected: BUILD SUCCEEDED.
- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/Swift/CrossCheck/CrossCheckGroupViewController.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(crosscheck): status group drill-in screen"
```

---

### Task 6: Rebuild `OSTCrossCheckViewController` (programmatic board)

**Files:**
- Replace contents: `OST Tracker/ViewControllers/OSTCrossCheckViewController.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (only if file path/group changes — it does not; keep in place)

**Interfaces:**
- Consumes: `CrossCheckPresentation` (build/sheetConfig), `CrossCheckExpectedCell`, `CrossCheckSummaryCell`, `CrossCheckActionSheet`, `CrossCheckGroupViewController`, `Theme`, `OSTBaseViewController`, `OSTBackend.shared.fetchNotExpected`, `EffortModel`, `CrossCheckEntriesModel`, `CurrentCourse`, `AppDelegate`.
- Produces: `@objc(OSTCrossCheckViewController) class OSTCrossCheckViewController` — instantiable directly via `OSTCrossCheckViewController()` (Task 7 uses this).

Keep these behaviors from the legacy VC: fetch efforts (`mr_findAllSorted(by:"bibNumber"...)`), the `fetchNotExpected` → bucketing flow, `checkIfEffortShouldBe(inSplit:selectedSplitName:)` filtering, the In/Out sub-split detection from `dataEntryGroups`, the Expected/Not-expected persistence via `CrossCheckEntriesModel` (create when marking not-expected, delete when marking expected) + `saveContext`, and routing **Review entries** to `AppDelegate.getInstance()?.showReview()`.

- [ ] **Step 1: Replace the file**

Overwrite `OSTCrossCheckViewController.swift` with:

```swift
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

        menuBtn.setTitle("Menu \u{2630}", for: .normal)
        menuBtn.setTitleColor(Theme.tint, for: .normal)
        menuBtn.titleLabel?.font = Theme.Font.button
        menuBtn.addTarget(self, action: #selector(onMenu), for: .touchUpInside)

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
```

> Notes for the implementer:
> - Confirm `OSTBackend.shared.fetchNotExpected(groupId:splitName:)` and the `EffortModel` method signatures match the legacy file (they were copied from it). If the bridged Swift selector differs (e.g. `checkIfEffortShouldBe(inSplit:selectedSplitName:)`), match the legacy call exactly.
> - `OSTBaseViewController` provides `menuButton`, `badgeLabel`, `updateSyncBadge()`, `ostPositionBadgeAtMenu()` (see `OSTReviewSubmitViewController`).
> - If `Section(rawValue:)!` force-unwraps trip a linter, switch on `Section.allCases[indexPath.section]`.

- [ ] **Step 2: Build, verify it compiles**

Run the full build command. Expected: BUILD SUCCEEDED. (The storyboard still exists at this point and still references the VC by name — that's fine; Task 7 removes it.)

- [ ] **Step 3: Run the full test suite to confirm no regressions**

```
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad (9th generation)' 2>&1 | tail -25
```
Expected: TEST SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTCrossCheckViewController.swift"
git commit -m "feat(crosscheck): rebuild board as programmatic design-system screen"
```

---

### Task 7: Wire navigation + retire storyboard & Obj-C cell stack

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTRightMenuViewController.swift:203-209` (the `onCrossCheck` handler)
- Delete: `OST Tracker/ViewControllers/CrossCheck.storyboard`
- Delete: `OST Tracker/ViewControllers/OSTCrossCheckCell.{h,m}`, `OSTCrossCheckHeader.{h,m}`, `OSTCrossCheckFooter.{h,m}`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (remove all references to the deleted files)
- Possibly modify: the Obj-C bridging header (remove imports of the deleted cell/header/footer, if present)

**Interfaces:**
- Consumes: `OSTCrossCheckViewController()` (Task 6).

- [ ] **Step 1: Point the menu at the VC directly**

Replace the `onCrossCheck` body:

```swift
@objc private func onCrossCheck() {
    AppDelegate.getInstance()?.rightMenuVC.centerViewController = OSTCrossCheckViewController()
    AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
}
```

- [ ] **Step 2: Build, verify it compiles** (storyboard/cells still present but now unused by the menu). Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Check the bridging header**

Search for imports of the soon-deleted classes:

```bash
grep -rn "OSTCrossCheckCell\|OSTCrossCheckHeader\|OSTCrossCheckFooter" "OST Tracker" --include="*.h" --include="*.m" --include="*.swift"
```
Remove any `#import` of these from the bridging header / other files. (The rebuilt VC does not reference them.)

- [ ] **Step 4: Delete the storyboard and Obj-C cell stack**

```bash
git rm "OST Tracker/ViewControllers/CrossCheck.storyboard" \
       "OST Tracker/ViewControllers/OSTCrossCheckCell.h" "OST Tracker/ViewControllers/OSTCrossCheckCell.m" \
       "OST Tracker/ViewControllers/OSTCrossCheckHeader.h" "OST Tracker/ViewControllers/OSTCrossCheckHeader.m" \
       "OST Tracker/ViewControllers/OSTCrossCheckFooter.h" "OST Tracker/ViewControllers/OSTCrossCheckFooter.m"
```

- [ ] **Step 5: Remove their references from `project.pbxproj`**

Remove every `PBXBuildFile`, `PBXFileReference`, group child entry, and `Sources`/`Resources` build-phase entry that names `CrossCheck.storyboard`, `OSTCrossCheckCell`, `OSTCrossCheckHeader`, or `OSTCrossCheckFooter`. After editing, verify the project still parses:

```bash
plutil -lint "OST Tracker.xcodeproj/project.pbxproj"
grep -n "OSTCrossCheckCell\|OSTCrossCheckHeader\|OSTCrossCheckFooter\|CrossCheck.storyboard" "OST Tracker.xcodeproj/project.pbxproj"
```
The grep must return nothing.

- [ ] **Step 6: Build + full test, verify clean**

Run the full build, then the full test suite. Expected: BUILD SUCCEEDED, TEST SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(crosscheck): route menu to native VC; retire storyboard + Obj-C cells"
```

---

### Task 8: Final verification pass

**Files:** none (verification only).

- [ ] **Step 1: Full clean build + test**

```
xcodebuild clean test -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad (9th generation)' 2>&1 | tail -30
```
Expected: TEST SUCCEEDED.

- [ ] **Step 2: Confirm nothing references removed symbols**

```bash
grep -rn "OSTCheckmarkView\|bulkSelect\|OSTCrossCheckCell" "OST Tracker" --include="*.swift" | grep -i crosscheck
```
The rebuilt VC should not reference bulk-select or the old cell. (`OSTCheckmarkView` may still exist for other screens — only confirm Cross Check no longer uses it.)

- [ ] **Step 3: Hand off for human visual verification**

Summarize for the user: the screen to open (right menu → Cross Check), what to check (Expected list scannable; summary rows drill in; tapping a bib opens the sheet; In/Out toggle on in/out stations; amber Expected accent; no bulk-select). Do **not** drive the simulator.

---

## Self-Review

**Spec coverage:**
- New design system look → Tasks 1, 3, 6 (Theme.warning, themed cells, programmatic VC). ✓
- "Still out / Expected" top list + summary rows → Task 6. ✓
- In/Out toggle → Task 6 (`resolveSplitName`/`configureInOutControl`/`onInOutChanged`). ✓
- Per-bib action sheet replacing bulk-select → Tasks 4, 6. ✓
- Drill-in screens → Task 5, wired in Task 6. ✓
- Status computation reuse + server not-expected preserved → Task 6 (`facts`, `applyServerNotExpected`). ✓
- Amber accent + `Theme.warning` addition → Task 1, mapped in Task 3. ✓
- Remove bulk-select, checkmark footer, full-tile fills, collection view, storyboard, Obj-C cells, dead "In Aid" → Tasks 6, 7. ✓
- Pure unit tests mirroring ReviewPresentation → Task 2 (membership, counts, status, "-1" exclusion, sheet config). ✓
- iOS 12 / programmatic / Theme constraints → Global Constraints + all tasks. ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete; pbxproj edits described concretely with verification greps. ✓

**Type consistency:** `CrossCheckRow`, `CrossCheckBoard`, `EffortFacts`, `CrossCheckStatus`, `CrossCheckSheetConfig`, `CrossCheckPresentation.build/status/sheetConfig`, `dotColor`, cell `reuseID`/`configure` signatures, and `CrossCheckGroupViewController`/`CrossCheckActionSheet` initializers are used identically across Tasks 2–6. ✓
