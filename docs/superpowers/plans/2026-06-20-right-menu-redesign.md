# Right-Menu Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the right-side navigation drawer as a clean, themed, programmatic Swift screen (no forest photo, legible list), retiring its XIB.

**Architecture:** A reusable `MenuRow` design-system control (title + chevron + count badge + optional spinner), and a Swift rewrite of `OSTRightMenuViewController` that subclasses the existing Obj-C `OSTBaseViewController` (keeping the `@objc` name so AppDelegate/`OSTDrawerContainer` are untouched), builds the panel with `Theme` + safe-area Auto Layout, and overrides the badge/sync-observer hooks.

**Tech Stack:** Swift + UIKit, XCTest. No third-party deps. Build/test from `OST Tracker.xcodeproj`.

## Global Constraints

- **iOS floor 12.0** (iPad mini 2/3). No SF Symbols / iOS 15 APIs; guard any iOS 13+ call (`UIActivityIndicatorView(style: .gray)` is iOS 12-safe; re-resolve `cgColor` in `traitCollectionDidChange`).
- **Theme-only styling** — colors/fonts/metrics from `Theme` (`OST Tracker/Swift/DesignSystem/`); never raw `UIColor` at call sites.
- **Module** `OST_Remote`; tests `@testable import OST_Remote`.
- **All work in the worktree:** `/Users/joneisen/dev/SplitTime/ost-remote-complete/.claude/worktrees/menu-redesign` on branch `worktree-menu-redesign`. Never touch the main repo checkout. Confirm `git branch --show-current` before any commit.
- **Register new files** with `ruby scripts/add_file_to_xcodeproj.rb "<path>" "OST Remote" "OST Remote Dev"` (tests → `"OST TrackerTests"`). Idempotent; do not hand-edit `project.pbxproj`. **Remove files** with `ruby scripts/remove_file_from_xcodeproj.rb "<basename>"`.
- **Test command** (booted local sim is **iPhone 17 Pro**, scheme **OST Remote Dev**):
  ```bash
  xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:"OST TrackerTests/<TestClass>"
  ```
- **Preserve** `@objc(OSTRightMenuViewController)`, its `init(nibName:bundle:)` initializer, and its subclassing of `OSTBaseViewController`. `AppDelegate` (`rightMenuViewController = [[OSTRightMenuViewController alloc] initWithNibName:nil bundle:nil]`) and `OSTDrawerContainer` stay unchanged. Nav action behavior is identical to today.
- **Reference implementation:** `OST Tracker/ViewControllers/OSTRaceStatusViewController.swift` is a Swift `OSTBaseViewController` subclass, fully themed, programmatic — follow its structure (`init(nibName:nil)`, `buildUI()` in `viewDidLoad`, safe-area layout, `ostShowBlockingSpinner`/`ostPresentAlert` helpers available).

## File Structure

- Create `OST Tracker/Swift/DesignSystem/MenuRow.swift` — themed nav row control.
- Rewrite `OST Tracker/ViewControllers/OSTRightMenuViewController.swift` (NEW Swift file replacing the Obj-C `.m`/`.h` + XIB).
- Delete `OST Tracker/ViewControllers/OSTRightMenuViewController.m`, `OSTRightMenuViewController.h`, `OSTRightMenuViewController.xib`.
- Test `OST TrackerTests/Swift/MenuRowTests.swift`.

---

### Task 1: MenuRow component

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/MenuRow.swift`
- Test: `OST TrackerTests/Swift/MenuRowTests.swift`

**Interfaces:**
- Produces: `final class MenuRow: UIControl` with `init(title: String)`, `let title: String`, `var badgeCount: Int { get set }` (>0 shows a red count pill, ==0 hides it), `var showsSpinner: Bool { get set }` (toggles a trailing activity indicator), and internal `var isShowingBadge: Bool { get }` (for tests).

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/MenuRowTests.swift
import XCTest
@testable import OST_Remote

final class MenuRowTests: XCTestCase {
    func test_title_isSet() {
        let row = MenuRow(title: "Review / Sync")
        XCTAssertEqual(row.title, "Review / Sync")
    }

    func test_badge_hiddenWhenZero() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 0
        XCTAssertFalse(row.isShowingBadge)
    }

    func test_badge_shownWithCountWhenPositive() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 6
        XCTAssertTrue(row.isShowingBadge)
        XCTAssertEqual(row.badgeText, "6")
    }

    func test_badge_hidesAgainWhenClearedToZero() {
        let row = MenuRow(title: "Review / Sync")
        row.badgeCount = 6
        row.badgeCount = 0
        XCTAssertFalse(row.isShowingBadge)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command with `-only-testing:"OST TrackerTests/MenuRowTests"`.
Expected: FAIL — `MenuRow` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/MenuRow.swift
import UIKit

/// One navigation row in the right menu: a title on the left, a trailing chevron,
/// an optional red count badge, and an optional spinner (for the syncing state).
/// Theme-styled. iOS 12-safe.
final class MenuRow: UIControl {

    let title: String

    private let titleLabel = UILabel()
    private let chevron = UILabel()
    private let badge = UILabel()
    private let spinner = UIActivityIndicatorView(style: .gray)

    init(title: String) {
        self.title = title
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = Theme.label
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = Theme.destructive
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        spinner.hidesWhenStopped = true

        chevron.text = "›"
        chevron.font = .systemFont(ofSize: 18, weight: .semibold)
        chevron.textColor = Theme.secondaryLabel

        let row = UIStackView(arrangedSubviews: [titleLabel, spinner, badge, chevron])
        row.alignment = .center
        row.spacing = 8
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 52),
            badge.heightAnchor.constraint(equalToConstant: 20),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    var badgeCount: Int = 0 {
        didSet {
            badge.isHidden = badgeCount <= 0
            badge.text = badgeCount > 0 ? "\(badgeCount)" : nil
        }
    }

    var showsSpinner: Bool = false {
        didSet { showsSpinner ? spinner.startAnimating() : spinner.stopAnimating() }
    }

    // Test seams.
    var isShowingBadge: Bool { !badge.isHidden }
    var badgeText: String? { badge.text }
}
```

Register: `ruby scripts/add_file_to_xcodeproj.rb "OST Tracker/Swift/DesignSystem/MenuRow.swift" "OST Remote" "OST Remote Dev"` and `ruby scripts/add_file_to_xcodeproj.rb "OST TrackerTests/Swift/MenuRowTests.swift" "OST TrackerTests"`.

- [ ] **Step 4: Run test to verify it passes**

Run with `-only-testing:"OST TrackerTests/MenuRowTests"`.
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/MenuRow.swift" "OST TrackerTests/Swift/MenuRowTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add MenuRow design-system control"
```

---

### Task 2: Rewrite OSTRightMenuViewController in Swift (retire XIB/Obj-C)

**Files:**
- Create: `OST Tracker/ViewControllers/OSTRightMenuViewController.swift`
- Delete: `OST Tracker/ViewControllers/OSTRightMenuViewController.m`, `OST Tracker/ViewControllers/OSTRightMenuViewController.h`, `OST Tracker/ViewControllers/OSTRightMenuViewController.xib`

**Interfaces:**
- Consumes: `MenuRow(title:)`, `Theme`, the Obj-C base `OSTBaseViewController` (badge: `badge`, `shouldShowBadge`, `updateSyncBadge()`; observer: `syncManagerDidStartSynchronization(_:)`, `syncManagerDidFinishSynchronization(_:)`, `syncManager(_:didFinishSynchronizationWithErrors:alternateServer:)`), `AutoSyncController.shared`, `AppDelegate.getInstance()`, `OSTRunnerTrackerViewController`, `OSTLiveReadsViewController`, `OSTRaceStatusViewController`.
- Produces: `@objc(OSTRightMenuViewController) final class OSTRightMenuViewController: OSTBaseViewController` with `init(nibName:bundle:)` (so `AppDelegate`'s `initWithNibName:nil bundle:nil` keeps working).

This is a behavior-preserving rewrite of the panel: same nav actions, same badge + auto-sync behavior, new clean themed layout, no XIB. There are no new unit tests for the VC (presentation + thin AppDelegate calls); the gate is a clean build + the full suite staying green, plus manual verification.

- [ ] **Step 1: Delete the Obj-C/XIB menu and de-register from the project**

```bash
ruby scripts/remove_file_from_xcodeproj.rb "OSTRightMenuViewController.m"
ruby scripts/remove_file_from_xcodeproj.rb "OSTRightMenuViewController.xib"
git rm "OST Tracker/ViewControllers/OSTRightMenuViewController.m" \
       "OST Tracker/ViewControllers/OSTRightMenuViewController.h" \
       "OST Tracker/ViewControllers/OSTRightMenuViewController.xib"
```
(The `.h` is a plain `PBXFileReference` with no build-file entry, so `git rm` plus the `.m` de-register is sufficient; if the project still references `OSTRightMenuViewController.h`, also run `ruby scripts/remove_file_from_xcodeproj.rb "OSTRightMenuViewController.h"`.)

Then remove its bridging-header import: in `OST Tracker/OST Tracker-Bridging-Header.h`, delete the `#import "OSTRightMenuViewController.h"` line if present (search for it). The new Swift class needs no bridging entry.

- [ ] **Step 2: Create the Swift menu**

```swift
// OST Tracker/ViewControllers/OSTRightMenuViewController.swift
import UIKit

/// Right-side navigation drawer, rebuilt onto the design system: a clean themed
/// list (no background photo), built programmatically. Subclasses the Obj-C
/// `OSTBaseViewController` for the unsynced-count badge + AutoSync observer.
/// Hosted by `OSTDrawerContainer` as its `rightMenuViewController`.
@objc(OSTRightMenuViewController)
final class OSTRightMenuViewController: OSTBaseViewController {

    private let liveEntryRow  = MenuRow(title: "Live Entry")
    private let reviewSyncRow  = MenuRow(title: "Review / Sync")
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
        // Header: Close (trailing) + brand.
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close ✕", for: .normal)
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
        brandLabel.font = .systemFont(ofSize: 22, weight: .bold)
        brandLabel.textColor = Theme.label
        let brandRow = UIStackView(arrangedSubviews: [logo, brandLabel, UIView()])
        brandRow.alignment = .center
        brandRow.spacing = 10

        // Grouped list card.
        liveEntryRow.addTarget(self, action: #selector(onLiveEntry), for: .touchUpInside)
        reviewSyncRow.addTarget(self, action: #selector(onReviewSync), for: .touchUpInside)
        crossCheckRow.addTarget(self, action: #selector(onCrossCheck), for: .touchUpInside)
        liveReadsRow.addTarget(self, action: #selector(onLiveReads), for: .touchUpInside)
        raceStatusRow.addTarget(self, action: #selector(onRaceStatus), for: .touchUpInside)
        utilitiesRow.addTarget(self, action: #selector(onUtilities), for: .touchUpInside)

        let rows = [liveEntryRow, reviewSyncRow, crossCheckRow, liveReadsRow, raceStatusRow, utilitiesRow]
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

        // Auto Sync footer row.
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
        reviewSyncRow.badgeCount = shouldShowBadge ? (Int(badge ?? "0") ?? 0) : 0
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
```

Register the new file: `ruby scripts/add_file_to_xcodeproj.rb "OST Tracker/ViewControllers/OSTRightMenuViewController.swift" "OST Remote" "OST Remote Dev"`.

- [ ] **Step 3: Reconcile method signatures against the Obj-C base, then build**

The override signatures above assume the Swift-imported names of the Obj-C methods. Before building, open the generated interface or the headers to confirm exact spellings:
- Base (`OST Tracker/ViewControllers/OSTBaseViewController.h`): `updateSyncBadge`, `badge` (an `NSString *`, imported as `String?`), `shouldShowBadge` (`Bool`).
- Observer (`OST Tracker/SyncManager/AutoSyncObserver.h`): `syncManagerDidStartSynchronization:`, `syncManagerDidFinishSynchronization:`, `syncManager:didFinishSynchronizationWithErrors:alternateServer:` (errors is `NSArray<NSError *> *`).
If the Swift importer spells a parameter type differently (e.g. `[Any]!` vs `[Error]!`), match the compiler's expected override signature exactly. Likewise confirm `AppDelegate.rightMenuVC` exposes `centerViewController` and `toggleRightSideMenuCompletion(_:)` to Swift, and that `OSTRunnerTrackerViewController.txtBibNumber` is accessible (it is `@objc`/public — used by the former Obj-C menu).

Then build + run the full suite:
```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD/TEST SUCCEEDED, the full suite green (MenuRow tests included). The Obj-C menu being gone must not break `AppDelegate`/`OSTDrawerContainer` (they reference only `OSTRightMenuViewController` + its `initWithNibName:` and the drawer API).

If an override signature can't be made to compile, STOP and report BLOCKED with the compiler's expected signature — do not change the base class.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTRightMenuViewController.swift" "OST Tracker/OST Tracker-Bridging-Header.h" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "refactor: rebuild right menu as programmatic themed Swift screen; retire XIB/Obj-C"
```

- [ ] **Step 5: Manual verification (human)**

Open the drawer: confirm the clean themed list (no photo), each row navigates (Live Entry→tracker, Review/Sync→review, Cross Check, Live Reads, Race Status, Utilities), the Review/Sync badge shows the unsynced count and clears after a sync, the sync spinner appears while syncing, the Auto Sync toggle reflects + persists the setting, Close dismisses the drawer (and refocuses the bib field when the tracker is centered), light + dark, and nothing hides under the Dynamic Island.

---

## Notes for the executor
- Run the full suite once more at the end (no `-only-testing`) to confirm the branch is green.
- `MenuRow` lives with the other design-system files under `OST Tracker/Swift/DesignSystem/`.
- Visual/interaction verification is handed to the user; do the code/build/unit-test work autonomously first.
