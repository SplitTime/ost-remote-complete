# Dissolve Utilities into the Right Menu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the standalone Utilities screen and move its actions (Refresh Roster, Change Station, Appearance, About, Logout) into the right-side navigation drawer, grouped into NAVIGATION and SETTINGS sections.

**Architecture:** Extend the existing `MenuRow` design-system component with a trailing detail label and an optional chevron, then rebuild `OSTRightMenuViewController` to host two `Theme.fieldFill` cards inside a scroll view plus a destructive Logout button. Action logic is ported verbatim from `OSTUtilitiesViewController`. The Utilities view controller, its XIB, and `AppDelegate.showUtilities` are then removed.

**Tech Stack:** Swift + UIKit (iOS 12 floor), programmatic Auto Layout, `Theme` design system, MagicalRecord-via-bridging CoreData, XCTest.

## Global Constraints

- iOS 12-safe: use `UIActivityIndicatorView(style: .gray)`; no APIs gated above iOS 12 without an `if #available` guard.
- All colors/fonts/metrics come from `Theme` — never hardcode colors.
- Tests: XCTest, `@testable import OST_Remote`, assert via public "test seam" properties (follow `OST TrackerTests/Swift/MenuRowTests.swift`).
- Build/test command (substitute any available sim from `xcrun simctl list devices available`):
  `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
- Preserve the base VC's unsynced-count badge + AutoSync observer wiring on the Review / Sync row (the `updateSyncBadge` / `syncManager…` overrides).
- Commit after each task.

---

### Task 1: Extend `MenuRow` with detail text + optional chevron

**Files:**
- Modify: `OST Tracker/Swift/DesignSystem/MenuRow.swift`
- Test: `OST TrackerTests/Swift/MenuRowTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `var detailText: String?` — trailing secondary label between badge and chevron; hidden when nil/empty.
  - `var showsChevron: Bool` (default `true`) — hides the chevron when `false`.
  - Test seams: `var detailLabelText: String?`, `var isShowingDetail: Bool`, `var isShowingChevron: Bool`.

- [ ] **Step 1: Write the failing tests**

Add to `OST TrackerTests/Swift/MenuRowTests.swift` (inside the existing class):

```swift
    func test_detailText_setsLabelAndShows() {
        let row = MenuRow(title: "Appearance")
        row.detailText = "System"
        XCTAssertEqual(row.detailLabelText, "System")
        XCTAssertTrue(row.isShowingDetail)
    }

    func test_detailText_hiddenWhenNil() {
        let row = MenuRow(title: "Appearance")
        XCTAssertFalse(row.isShowingDetail)
    }

    func test_detailText_hiddenWhenClearedToNil() {
        let row = MenuRow(title: "Appearance")
        row.detailText = "Dark"
        row.detailText = nil
        XCTAssertFalse(row.isShowingDetail)
    }

    func test_chevron_shownByDefault() {
        let row = MenuRow(title: "About")
        XCTAssertTrue(row.isShowingChevron)
    }

    func test_chevron_hiddenWhenShowsChevronFalse() {
        let row = MenuRow(title: "Refresh Roster")
        row.showsChevron = false
        XCTAssertFalse(row.isShowingChevron)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — compile error, `value of type 'MenuRow' has no member 'detailText' / 'detailLabelText' / 'isShowingDetail' / 'showsChevron' / 'isShowingChevron'`.

- [ ] **Step 3: Add the detail label + chevron toggle to `MenuRow`**

In `MenuRow.swift`, add a `detail` label property alongside the others:

```swift
    private let detail = UILabel()
```

In `init`, configure it (place these lines just before the `chevron.text = "›"` block):

```swift
        detail.font = .systemFont(ofSize: 15)
        detail.textColor = Theme.secondaryLabel
        detail.isHidden = true
```

Add `detail` to the row stack, between `badge` and `chevron`:

```swift
        let row = UIStackView(arrangedSubviews: [titleLabel, spinner, badge, detail, chevron])
```

Add the public properties and test seams (next to `badgeCount` / `showsSpinner`):

```swift
    var detailText: String? {
        didSet {
            detail.text = detailText
            detail.isHidden = (detailText?.isEmpty ?? true)
        }
    }

    var showsChevron: Bool = true {
        didSet { chevron.isHidden = !showsChevron }
    }

    var isShowingDetail: Bool { !detail.isHidden }
    var detailLabelText: String? { detail.text }
    var isShowingChevron: Bool { !chevron.isHidden }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS (all `MenuRowTests` green).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/MenuRow.swift" "OST TrackerTests/Swift/MenuRowTests.swift"
git commit -m "feat(menu-row): add detailText and optional chevron"
```

---

### Task 2: Add `AppearanceMode.displayName`

**Files:**
- Modify: `OST Tracker/Swift/DesignSystem/AppearanceController.swift`
- Test: `OST TrackerTests/Swift/AppearanceModeTests.swift` (create)

**Interfaces:**
- Consumes: existing `enum AppearanceMode { case system, light, dark }`.
- Produces: `var AppearanceMode.displayName: String` → "System" / "Light" / "Dark". Used by the Appearance row's detail text and the appearance picker.

- [ ] **Step 1: Write the failing test**

Create `OST TrackerTests/Swift/AppearanceModeTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class AppearanceModeTests: XCTestCase {
    func test_displayName_forEachMode() {
        XCTAssertEqual(AppearanceMode.system.displayName, "System")
        XCTAssertEqual(AppearanceMode.light.displayName, "Light")
        XCTAssertEqual(AppearanceMode.dark.displayName, "Dark")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: FAIL — compile error, `value of type 'AppearanceMode' has no member 'displayName'`.

> NOTE: This new test file must be added to the `OST TrackerTests` target. If the project does not auto-include it, add it via the same group as `MenuRowTests.swift` in `project.pbxproj` (mirror an existing test file's `PBXBuildFile` + `PBXFileReference` + group + Sources entries). Re-run after adding.

- [ ] **Step 3: Add the `displayName` computed property**

In `AppearanceController.swift`, after the `enum AppearanceMode { … }` block, add:

```swift
extension AppearanceMode {
    /// Human-readable label for menus / pickers.
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/AppearanceController.swift" "OST TrackerTests/Swift/AppearanceModeTests.swift"
git commit -m "feat(appearance): add AppearanceMode.displayName"
```

---

### Task 3: Generalize `OSTToast` to accept a custom message

**Files:**
- Modify: `OST Tracker/Swift/AutoSync/OSTToast.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `@objc static func show(message: String, success: Bool)` — renders an arbitrary message with the success/failure background color. Existing `show(success:)` delegates to it. Used by Task 4's Refresh Roster.

> NOTE: No unit test — `OSTToast` renders into `AppDelegate.window` and auto-dismisses; there is no pure unit to assert. This is a mechanical refactor verified by a green build and Task 4's manual check. (The project verifies UIKit-window glue by build + manual, per established practice.)

- [ ] **Step 1: Refactor into a message-carrying method**

Replace the body of `OSTToast` (the `show(success:)` method) with:

```swift
    /// Green "synced successfully" on success, red "failed to sync" otherwise.
    @objc static func show(success: Bool) {
        let message = success ? "Times synced successfully." : "Failed to sync times."
        show(message: message, success: success)
    }

    /// Same toast with a caller-supplied message.
    @objc static func show(message: String, success: Bool) {
        guard let window = AppDelegate.getInstance()?.window else { return }

        let bg = success
            ? UIColor(red: 88/255, green: 182/255, blue: 73/255, alpha: 1)
            : UIColor(red: 247/255, green: 45/255, blue: 0, alpha: 1)

        DispatchQueue.main.async {
            let toast = UILabel()
            toast.text = message
            toast.textColor = .black
            toast.textAlignment = .center
            toast.numberOfLines = 0
            toast.backgroundColor = bg
            toast.font = .systemFont(ofSize: 16)
            toast.layer.cornerRadius = 10
            toast.clipsToBounds = true
            toast.isUserInteractionEnabled = true
            toast.addGestureRecognizer(UITapGestureRecognizer(target: toast, action: #selector(UIView.removeFromSuperview)))

            let maxWidth = window.bounds.size.width - 40
            let fit = toast.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
            let w = min(fit.width + 30, maxWidth)
            let h = fit.height + 20
            let top = window.safeAreaInsets.top + 10
            toast.frame = CGRect(x: (window.bounds.size.width - w) / 2, y: top, width: w, height: h)
            toast.alpha = 0
            window.addSubview(toast)

            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 1 }) { _ in
                UIView.animate(withDuration: 0.3, delay: 3.0, options: [], animations: { toast.alpha = 0 }) { _ in
                    toast.removeFromSuperview()
                }
            }
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "OST Tracker/Swift/AutoSync/OSTToast.swift"
git commit -m "refactor(toast): add custom-message overload"
```

---

### Task 4: Rebuild `OSTRightMenuViewController` with NAVIGATION + SETTINGS sections

**Files:**
- Modify (full rewrite): `OST Tracker/ViewControllers/OSTRightMenuViewController.swift`

**Interfaces:**
- Consumes: `MenuRow.detailText`, `MenuRow.showsChevron` (Task 1); `AppearanceMode.displayName` (Task 2); `OSTToast.show(message:success:)` (Task 3); existing `OSTBackend.shared.getEventsDetails(_:completion:)`, `OSTBackend.shared.verifyConnection(completion:)`, `OSTEventSelectionViewController(nibName:bundle:)` + `.changeStation`, `BottomSheetPicker.present(from:title:options:selected:onSelect:)`, `AppearanceController.shared.mode`, `AppDelegate.getInstance()` (`rightMenuVC`, `showAbout()`, `logout()`).
- Produces: a self-contained drawer; no other file depends on it beyond `AppDelegate` already setting it as `rightMenuViewController`.

> NOTE: VC wiring is verified by a green build + the manual checklist at the end of this task (UIKit drawer behavior has no pure unit). The ported action logic is unchanged from `OSTUtilitiesViewController`.

- [ ] **Step 1: Replace the file with the rebuilt menu**

Overwrite `OST Tracker/ViewControllers/OSTRightMenuViewController.swift` with:

```swift
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
    private let raceStatusRow = MenuRow(title: "Race Status")

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
        raceStatusRow.addTarget(self, action: #selector(onRaceStatus), for: .touchUpInside)
        let navCard = makeCard(rows: [liveEntryRow, reviewSyncRow, crossCheckRow, liveReadsRow, raceStatusRow])

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

            NSManagedObjectContext.mr_default().processPendingChanges()
            NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
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

    // MARK: - Logout (ported from OSTUtilitiesViewController)

    @objc private func onLogout() {
        let checking = UIAlertController(title: "Checking connection…",
                                         message: "\n\n",
                                         preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .gray)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        checking.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: checking.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: checking.view.bottomAnchor, constant: -16)
        ])
        present(checking, animated: true)

        OSTBackend.shared.verifyConnection { [weak self] error in
            guard let self = self else { return }
            checking.dismiss(animated: true) {
                if error == nil {
                    self.presentLogoutConfirmation()
                } else {
                    self.presentLogoutOverride()
                }
            }
        }
    }

    /// Online: confirm, then log out.
    private func presentLogoutConfirmation() {
        let alert = UIAlertController(title: "Are you sure you would like to log out?",
                                      message: "You can log back in using your current connection, but you won't be able to add entries or log back in if you lose it.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    /// Check failed: block, but allow an immediate override.
    private func presentLogoutOverride() {
        let alert = UIAlertController(title: "Can't reach OpenSplitTime",
                                      message: "You will not be able to log back in or add entries until you have a data connection again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out Anyway", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    private func performLogout() {
        let app = AppDelegate.getInstance()
        app?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        app?.logout()
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build`
Expected: BUILD SUCCEEDED.

> If the build fails on `currentCourse.eventId`, `EffortModel.mr_reconcile`, or `NSManagedObjectContext.mr_default()`, confirm `import CoreData` is present (it is, at the top) — these bridge in exactly as they did in `OSTUtilitiesViewController.swift`.

- [ ] **Step 3: Run the test suite to confirm nothing regressed**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: PASS (existing + Task 1/2 tests green).

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTRightMenuViewController.swift"
git commit -m "feat(menu): fold Utilities actions into NAVIGATION + SETTINGS sections"
```

- [ ] **Step 5: Manual verification (hand to user)**

Open the drawer and confirm: two cards render (NAVIGATION: Live Entry / Review·Sync / Cross Check / Live Reads / Race Status; SETTINGS: Refresh Roster / Change Station / Appearance / About), the list scrolls on a phone, Review/Sync still shows its unsynced badge + sync spinner. Tap **Refresh Roster** → inline spinner → "Roster updated." toast (and force an error → Retry alert). **Change Station** → drawer closes, event selection opens in change-station mode. **Appearance** → bottom-sheet opens, choosing a mode updates the row's detail text and theme. **About** → navigates. **Auto Sync** toggle still works. **Log Out** → connection-check → confirm/override flow.

---

### Task 5: Delete the Utilities screen, its XIB, and `showUtilities`

**Files:**
- Delete: `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift`
- Delete: `OST Tracker/ViewControllers/OSTUtilitiesViewController.xib`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (remove all `OSTUtilitiesViewController` references)
- Modify: `OST Tracker/AppDelegate.m` (remove `showUtilities`)
- Modify: `OST Tracker/AppDelegate.h` (remove `showUtilities` declaration if present)

**Interfaces:**
- Consumes: nothing. This is pure removal; Task 4 already replaced the only caller of `showUtilities`.
- Produces: nothing.

- [ ] **Step 1: Confirm nothing still references the screen**

Run:
```bash
grep -rn "showUtilities\|OSTUtilitiesViewController" "OST Tracker" --include=*.swift --include=*.m --include=*.h
```
Expected: matches only in `AppDelegate.m` (the `showUtilities` method, and possibly its `#import`/comment) and `AppDelegate.h` (if it declares `showUtilities`). The menu no longer references either (verify no `OSTRightMenuViewController` match). If any *other* file matches, stop and resolve before deleting.

- [ ] **Step 2: Delete the two source files**

```bash
git rm "OST Tracker/ViewControllers/OSTUtilitiesViewController.swift" "OST Tracker/ViewControllers/OSTUtilitiesViewController.xib"
```

- [ ] **Step 3: Remove `showUtilities` from AppDelegate**

In `OST Tracker/AppDelegate.m`, delete the whole method:

```objc
- (void) showUtilities
{
    self.rightMenuVC.centerViewController = [[OSTUtilitiesViewController alloc] initWithNibName:nil bundle:nil];
    ...
}
```

(Delete the entire method body through its closing `}`.) Also remove any `#import "OSTUtilitiesViewController.h"` line and the stale `// OSTUtilitiesViewController and OSTAboutViewController are now Swift` comment if it only concerns Utilities. In `OST Tracker/AppDelegate.h`, remove the `- (void) showUtilities;` declaration if it exists.

- [ ] **Step 4: Remove the project references from `project.pbxproj`**

Remove every line in `OST Tracker.xcodeproj/project.pbxproj` that mentions `OSTUtilitiesViewController` — these come in matched sets: `PBXBuildFile` entries (`… OSTUtilitiesViewController.swift in Sources`, `… .xib in Resources`, for both the "OST Remote" and "OST Remote Dev" targets), the two `PBXFileReference` entries, the two group `children` entries, and the `Sources` / `Resources` build-phase entries. After editing, verify none remain:

```bash
grep -n "OSTUtilitiesViewController" "OST Tracker.xcodeproj/project.pbxproj"
```
Expected: no output.

- [ ] **Step 5: Build + test to verify the project is still valid**

Run: `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test`
Expected: BUILD SUCCEEDED and all tests PASS. (A broken pbxproj edit typically fails with "Build input file cannot be found" or a project-parse error — if so, restore the file refs you removed in matched sets.)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: remove Utilities screen, XIB, and showUtilities"
```

---

## Self-Review

**Spec coverage:**
- Drawer layout (two cards, section headers, scroll, Auto Sync repositioned, Logout button) → Task 4. ✓
- `MenuRow` detail text + optional chevron → Task 1. ✓
- Refresh Roster (rename + inline spinner + toast + Retry alert, ported reconcile logic) → Task 4 (`onRefreshRoster`), toast enabled by Task 3. ✓
- Change Station / Appearance (BottomSheetPicker + detail) / About / Logout (two-path) → Task 4. ✓
- Appearance current-mode label → Task 2. ✓
- `OSTToast` generalization → Task 3. ✓
- Remove Utilities VC + XIB + `showUtilities` + project refs → Task 5. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `detailText` / `showsChevron` / `isShowingDetail` / `detailLabelText` / `isShowingChevron` (Task 1) used consistently in Task 4. `AppearanceMode.displayName` (Task 2) used in Task 4. `OSTToast.show(message:success:)` (Task 3) called with the same label in Task 4. Ported symbols (`getEventsDetails`, `verifyConnection`, `mr_reconcile(fromIncluded:ofType:)`, `mr_default()`, `mr_saveOnlySelfAndWait()`, `BottomSheetPicker.present(from:title:options:selected:onSelect:)`) match the verified existing signatures. ✓
