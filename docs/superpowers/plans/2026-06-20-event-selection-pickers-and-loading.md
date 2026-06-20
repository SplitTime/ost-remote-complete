# Event-Selection Pickers & Loading Rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the event-selection screen's two inline-expand pickers with an open selector for events and a bottom-drawer picker for the aid station, add a present-first loading state and a screen title/instructions, and remove the now-unused `DisclosureSelectField`.

**Architecture:** Two new theme-styled design-system pieces — `SelectableOptionList` (open single-select rows) and `BottomSheetPicker` (iOS 12-safe slide-up drawer). `OSTEventSelectionViewController` is reworked to present immediately with a loading spinner, fetch events itself, show events in the open selector, and open the aid-station drawer on tap. Public `@objc` API and the post-selection data path are preserved.

**Tech Stack:** Swift + UIKit, XCTest. No third-party deps. Build/test from `OST Tracker.xcodeproj`.

## Global Constraints

- **iOS floor 12.0** (iPad mini 2/3). No `UISheetPresentationController` / iOS 15 APIs. Any iOS 13+ API guarded with `#available`.
- **Theme-only styling** — colors/fonts/metrics from `Theme` (see `OST Tracker/Swift/DesignSystem/`); never raw `UIColor` at call sites.
- **Module** `OST_Remote`; tests `@testable import OST_Remote`.
- **All work in the worktree:** `/Users/joneisen/dev/SplitTime/ost-remote-complete/.claude/worktrees/login-event-redesign` on branch `worktree-login-event-redesign`. Never touch the main repo checkout. Confirm `git branch --show-current` before any commit.
- **Register new files** with `ruby scripts/add_file_to_xcodeproj.rb "<path>" "OST Remote" "OST Remote Dev"` (tests → `"OST TrackerTests"`). Idempotent; do not hand-edit `project.pbxproj`.
- **Test command** (booted local sim is **iPhone 17 Pro**, scheme **OST Remote Dev**):
  ```bash
  xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:"OST TrackerTests/<TestClass>"
  ```
- **Preserve** `OSTEventSelectionViewController`'s `@objc(OSTEventSelectionViewController)` name, its `@objc` members (`changeStation`, `tempContext`, `events`, `eventStrings`, `loadEventDataAndPresent(from:completion:)`), and the entire `onNext` post-selection data path. The two callers (`LoginViewController`, `OSTUtilitiesViewController.onChangeStation`) stay unchanged.

## File Structure

- Create `OST Tracker/Swift/DesignSystem/SelectableOptionList.swift` — open single-select list (events).
- Create `OST Tracker/Swift/DesignSystem/BottomSheetPicker.swift` — slide-up drawer (aid station).
- Modify `OST Tracker/ViewControllers/OSTEventSelectionViewController.swift` — rework UI + loading + flow.
- Delete `OST Tracker/Swift/DesignSystem/DisclosureSelectField.swift` and `OST TrackerTests/Swift/DisclosureSelectFieldTests.swift`.
- Tests: `OST TrackerTests/Swift/SelectableOptionListTests.swift`, `OST TrackerTests/Swift/BottomSheetPickerTests.swift`.

---

### Task 1: SelectableOptionList (open selector)

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/SelectableOptionList.swift`
- Test: `OST TrackerTests/Swift/SelectableOptionListTests.swift`

**Interfaces:**
- Produces: `final class SelectableOptionList: UIView` with `init(label: String)`, `var options: [String] { get set }` (setter rebuilds rows), `private(set) var selectedOption: String?`, `var onSelect: ((String) -> Void)?`, `func select(_ option: String)`, `func reset()`.

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/SelectableOptionListTests.swift
import XCTest
@testable import OST_Remote

final class SelectableOptionListTests: XCTestCase {
    func test_select_setsSelection_andFiresCallback() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["Bear 100 — 2026", "Wasatch 100"]
        var fired: String?
        list.onSelect = { fired = $0 }
        list.select("Wasatch 100")
        XCTAssertEqual(list.selectedOption, "Wasatch 100")
        XCTAssertEqual(fired, "Wasatch 100")
    }

    func test_select_ignoresUnknownOption() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("Nope")
        XCTAssertNil(list.selectedOption)
    }

    func test_reset_clearsSelection() {
        let list = SelectableOptionList(label: "Event")
        list.options = ["A", "B"]
        list.select("A")
        list.reset()
        XCTAssertNil(list.selectedOption)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command with `-only-testing:"OST TrackerTests/SelectableOptionListTests"`.
Expected: FAIL — `SelectableOptionList` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/SelectableOptionList.swift
import UIKit

/// Open single-select list: a section label plus one tappable row per option, each
/// with a trailing radio indicator. For short lists (e.g. live-mode events) shown
/// directly, with no dropdown. Theme-styled.
final class SelectableOptionList: UIView {

    var options: [String] = [] { didSet { rebuildRows() } }
    private(set) var selectedOption: String?
    var onSelect: ((String) -> Void)?

    private let rowsStack = UIStackView()

    init(label: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let caption = UILabel()
        caption.text = label.uppercased()
        caption.font = Theme.Font.caption
        caption.textColor = Theme.secondaryLabel

        rowsStack.axis = .vertical
        rowsStack.spacing = 8

        let outer = UIStackView(arrangedSubviews: [caption, rowsStack])
        outer.axis = .vertical
        outer.spacing = 8
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor),
            outer.topAnchor.constraint(equalTo: topAnchor),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func select(_ option: String) {
        guard options.contains(option) else { return }
        selectedOption = option
        refreshSelection()
        onSelect?(option)
    }

    func reset() {
        selectedOption = nil
        refreshSelection()
    }

    private func rebuildRows() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for option in options {
            let row = OptionRow(title: option)
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            rowsStack.addArrangedSubview(row)
        }
        refreshSelection()
    }

    @objc private func rowTapped(_ sender: OptionRow) {
        select(sender.title)
    }

    private func refreshSelection() {
        for case let row as OptionRow in rowsStack.arrangedSubviews {
            row.isSelectedOption = (row.title == selectedOption)
        }
    }
}

/// One selectable row: title on the left, radio indicator on the right.
private final class OptionRow: UIControl {
    let title: String
    private let radio = UIView()

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        backgroundColor = Theme.fieldFill
        layer.cornerRadius = Theme.Metric.cornerRadius
        layer.borderWidth = 1
        layer.borderColor = Theme.separator.cgColor

        let label = UILabel()
        label.text = title
        label.font = Theme.Font.field
        label.textColor = Theme.label

        radio.translatesAutoresizingMaskIntoConstraints = false
        radio.layer.cornerRadius = 9
        radio.layer.borderWidth = 2
        radio.layer.borderColor = Theme.separator.cgColor
        radio.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [label, radio])
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: Theme.Metric.fieldHeight),
            radio.widthAnchor.constraint(equalToConstant: 18),
            radio.heightAnchor.constraint(equalToConstant: 18),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    var isSelectedOption: Bool = false {
        didSet { applySelectionStyle() }
    }

    private func applySelectionStyle() {
        layer.borderColor = (isSelectedOption ? Theme.tint : Theme.separator).cgColor
        layer.borderWidth = isSelectedOption ? 2 : 1
        radio.backgroundColor = isSelectedOption ? Theme.tint : .clear
        radio.layer.borderColor = (isSelectedOption ? Theme.tint : Theme.separator).cgColor
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applySelectionStyle()
        }
    }
}
```

Register: `ruby scripts/add_file_to_xcodeproj.rb "OST Tracker/Swift/DesignSystem/SelectableOptionList.swift" "OST Remote" "OST Remote Dev"` and `ruby scripts/add_file_to_xcodeproj.rb "OST TrackerTests/Swift/SelectableOptionListTests.swift" "OST TrackerTests"`.

- [ ] **Step 4: Run test to verify it passes**

Run the test command with `-only-testing:"OST TrackerTests/SelectableOptionListTests"`.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/SelectableOptionList.swift" "OST TrackerTests/Swift/SelectableOptionListTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add SelectableOptionList open selector component"
```

---

### Task 2: BottomSheetPicker (aid-station drawer)

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/BottomSheetPicker.swift`
- Test: `OST TrackerTests/Swift/BottomSheetPickerTests.swift`

**Interfaces:**
- Produces: `final class BottomSheetPicker: UIViewController` with `init(title: String, options: [String], selected: String?, onSelect: @escaping (String) -> Void)`, `static func present(from presenter: UIViewController, title: String, options: [String], selected: String?, onSelect: @escaping (String) -> Void)`, and internal `func choose(_ option: String)` (fires `onSelect` then dismisses) — `choose` is the testable seam.

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/BottomSheetPickerTests.swift
import XCTest
@testable import OST_Remote

final class BottomSheetPickerTests: XCTestCase {
    func test_choose_firesCallbackWithOption() {
        var fired: String?
        let sheet = BottomSheetPicker(title: "Aid Station",
                                      options: ["Tony Grove", "Temple Fork"],
                                      selected: nil) { fired = $0 }
        sheet.loadViewIfNeeded()
        sheet.choose("Temple Fork")
        XCTAssertEqual(fired, "Temple Fork")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:"OST TrackerTests/BottomSheetPickerTests"`.
Expected: FAIL — `BottomSheetPicker` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/BottomSheetPicker.swift
import UIKit

/// Slide-up bottom drawer for selecting from a list. iOS 12-safe (no
/// UISheetPresentationController): presented over full screen with a dimmed,
/// tap-to-dismiss scrim and a constraint-animated bottom panel. Theme-styled.
final class BottomSheetPicker: UIViewController {

    private let sheetTitle: String
    private let options: [String]
    private let preselected: String?
    private let onSelect: (String) -> Void

    private let scrim = UIView()
    private let panel = UIView()
    private var panelBottom: NSLayoutConstraint!

    init(title: String, options: [String], selected: String?, onSelect: @escaping (String) -> Void) {
        self.sheetTitle = title
        self.options = options
        self.preselected = selected
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    static func present(from presenter: UIViewController, title: String, options: [String],
                        selected: String?, onSelect: @escaping (String) -> Void) {
        let vc = BottomSheetPicker(title: title, options: options, selected: selected, onSelect: onSelect)
        presenter.present(vc, animated: false) { vc.animateIn() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrim.backgroundColor = UIColor.black.withAlphaComponent(0)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        view.addSubview(scrim)

        panel.backgroundColor = Theme.background
        panel.layer.cornerRadius = 16
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let grab = UIView()
        grab.backgroundColor = Theme.separator
        grab.layer.cornerRadius = 2.5
        grab.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = sheetTitle
        header.font = Theme.Font.button
        header.textColor = Theme.label
        header.textAlignment = .center

        let rows = UIStackView()
        rows.axis = .vertical
        for option in options {
            let row = SheetRow(title: option, checked: option == preselected)
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            rows.addArrangedSubview(row)
        }
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(rows)

        let content = UIStackView(arrangedSubviews: [grab, header, scroll])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(8, after: grab)
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(content)

        panelBottom = panel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 600) // start off-screen
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelBottom,
            panel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),

            grab.widthAnchor.constraint(equalToConstant: 36),
            grab.heightAnchor.constraint(equalToConstant: 5),
            grab.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            content.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            content.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            rows.topAnchor.constraint(equalTo: scroll.topAnchor),
            rows.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            rows.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
    }

    func animateIn() {
        view.layoutIfNeeded()
        panelBottom.constant = 0
        UIView.animate(withDuration: 0.28) {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            self.view.layoutIfNeeded()
        }
    }

    private func animateOut(then completion: (() -> Void)?) {
        panelBottom.constant = 600
        UIView.animate(withDuration: 0.22, animations: {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0)
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    /// Testable seam: select an option (fires callback, then dismisses).
    func choose(_ option: String) {
        onSelect(option)
        animateOut(then: nil)
    }

    @objc private func rowTapped(_ sender: SheetRow) { choose(sender.title) }
    @objc private func dismissTapped() { animateOut(then: nil) }
}

private final class SheetRow: UIControl {
    let title: String
    init(title: String, checked: Bool) {
        self.title = title
        super.init(frame: .zero)
        backgroundColor = Theme.fieldFill

        let label = UILabel()
        label.text = title
        label.font = Theme.Font.field
        label.textColor = checked ? Theme.tint : Theme.label

        let check = UILabel()
        check.text = checked ? "✓" : ""
        check.textColor = Theme.tint
        check.font = Theme.Font.field

        let sep = UIView()
        sep.backgroundColor = Theme.separator
        sep.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [label, check])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)
        addSubview(sep)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 52),
            sep.heightAnchor.constraint(equalToConstant: 1),
            sep.leadingAnchor.constraint(equalTo: leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}
```

Register: `ruby scripts/add_file_to_xcodeproj.rb "OST Tracker/Swift/DesignSystem/BottomSheetPicker.swift" "OST Remote" "OST Remote Dev"` and `ruby scripts/add_file_to_xcodeproj.rb "OST TrackerTests/Swift/BottomSheetPickerTests.swift" "OST TrackerTests"`.

- [ ] **Step 4: Run test to verify it passes**

Run with `-only-testing:"OST TrackerTests/BottomSheetPickerTests"`.
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/BottomSheetPicker.swift" "OST TrackerTests/Swift/BottomSheetPickerTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add BottomSheetPicker drawer component"
```

---

### Task 3: Rework OSTEventSelectionViewController

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTEventSelectionViewController.swift`

**Interfaces:**
- Consumes: `SelectableOptionList(label:)`, `BottomSheetPicker.present(from:title:options:selected:onSelect:)`, `Theme`, `PrimaryButton`.
- Preserves: `@objc(OSTEventSelectionViewController)`, `@objc` members, and the `onNext` data path verbatim except where selections are read.

This task replaces the screen's view construction and loading flow. **Read the current file fully first.** Keep `onNext`'s post-selection block (the `OSTBackend.getEventsDetails` closure: `CurrentCourse` creation/population, `EffortModel.mr_reconcile`, saves, `loadLeftMenu`/`showTracker`) and `onLogout`/`onCancel` exactly as they are today; only the items below change.

- [ ] **Step 1: Replace the views and `loadEventDataAndPresent` (present-first)**

Replace the `// MARK: - Programmatic views` block and the `loadEventDataAndPresent` class method with:

```swift
// MARK: - Programmatic views
private let titleLabel: UILabel = {
    let l = UILabel(); l.text = "Select Event & Aid Station"
    l.font = Theme.Font.title; l.textColor = Theme.label
    l.numberOfLines = 0; return l
}()
private let hintLabel: UILabel = {
    let l = UILabel(); l.text = "Choose your event, then your aid station."
    l.font = Theme.Font.field; l.textColor = Theme.secondaryLabel
    l.numberOfLines = 0; return l
}()
private let eventList = SelectableOptionList(label: "Event")
private let aidStationField = AidStationField()
private let nextButton = PrimaryButton(title: "Start Tracking", role: .success)
private let logoutButton: UIButton = {
    let b = UIButton(type: .system); b.setTitle("Log Out", for: .normal)
    b.setTitleColor(Theme.destructive, for: .normal); return b
}()
private let cancelButton: UIButton = {
    let b = UIButton(type: .system); b.setTitle("Cancel", for: .normal)
    b.setTitleColor(Theme.tint, for: .normal); return b
}()
private let loadingSpinner: UIActivityIndicatorView = {
    let s = UIActivityIndicatorView(style: .gray); s.hidesWhenStopped = true; return s
}()
private let loadingLabel: UILabel = {
    let l = UILabel(); l.text = "Loading events…"; l.textColor = Theme.secondaryLabel
    l.font = Theme.Font.field; l.textAlignment = .center; l.isHidden = true; return l
}()
// Kept from before for the post-selection download state:
private let progressLabel: UILabel = {
    let l = UILabel(); l.textAlignment = .center; l.textColor = Theme.secondaryLabel
    l.font = Theme.Font.field; l.isHidden = true; return l
}()
private let progressBar: UIProgressView = {
    let p = UIProgressView(progressViewStyle: .default); p.isHidden = true; return p
}()

@objc class func loadEventDataAndPresent(from presenter: UIViewController,
                                         completion: ((Error?) -> Void)? = nil) {
    let eventVC = OSTEventSelectionViewController(nibName: nil, bundle: nil)
    eventVC.tempContext = NSManagedObjectContext.mr_context(withParent: NSManagedObjectContext.mr_default())
    eventVC.modalPresentationStyle = .fullScreen
    // Present immediately in the loading state; the VC fetches events itself.
    presenter.present(eventVC, animated: true) { completion?(nil) }
}
```

- [ ] **Step 2: Add the `AidStationField` inline control (file-private)**

At the bottom of the file (outside the VC class) add:

```swift
/// Tappable field row for the aid station: label + current value/placeholder +
/// chevron. Opens the BottomSheetPicker on tap (wired by the VC). Theme-styled.
private final class AidStationField: UIControl {
    private let valueLabel = UILabel()
    private let placeholder = "Choose an aid station"

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.fieldFill
        layer.cornerRadius = Theme.Metric.cornerRadius
        layer.borderWidth = 1
        layer.borderColor = Theme.separator.cgColor

        let caption = UILabel()
        caption.text = "AID STATION"; caption.font = Theme.Font.caption; caption.textColor = Theme.secondaryLabel

        valueLabel.text = placeholder; valueLabel.font = Theme.Font.field; valueLabel.textColor = Theme.secondaryLabel
        let chevron = UILabel(); chevron.text = "▾"; chevron.textColor = Theme.secondaryLabel

        let valueRow = UIStackView(arrangedSubviews: [valueLabel, chevron])
        valueRow.alignment = .center
        let outer = UIStackView(arrangedSubviews: [caption, valueRow])
        outer.axis = .vertical; outer.spacing = 4
        outer.isUserInteractionEnabled = false
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            outer.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    var value: String? {
        didSet {
            valueLabel.text = value ?? placeholder
            valueLabel.textColor = value == nil ? Theme.secondaryLabel : Theme.label
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            layer.borderColor = Theme.separator.cgColor
        }
    }
}
```

- [ ] **Step 3: Rebuild `viewDidLoad` (layout + wiring + loading)**

Replace `viewDidLoad` with:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Theme.background

    nextButton.alpha = 0
    aidStationField.isHidden = true
    aidStationField.isEnabled = false
    nextButton.addTarget(self, action: #selector(onNext(_:)), for: .touchUpInside)
    logoutButton.addTarget(self, action: #selector(onLogout(_:)), for: .touchUpInside)
    cancelButton.addTarget(self, action: #selector(onCancel(_:)), for: .touchUpInside)
    aidStationField.addTarget(self, action: #selector(openAidStationPicker), for: .touchUpInside)

    eventList.onSelect = { [weak self] _ in self?.onEventSelected() }

    let footer = changeStation ? cancelButton : logoutButton
    let loadingRow = UIStackView(arrangedSubviews: [loadingSpinner, loadingLabel])
    loadingRow.axis = .vertical; loadingRow.spacing = 10; loadingRow.alignment = .center

    let stack = UIStackView(arrangedSubviews: [titleLabel, hintLabel, eventList, aidStationField,
                                               nextButton, loadingRow, progressLabel, progressBar, footer])
    stack.axis = .vertical
    stack.spacing = 16
    stack.setCustomSpacing(4, after: titleLabel)
    stack.setCustomSpacing(22, after: hintLabel)
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Theme.Metric.horizontalInset),
        stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Theme.Metric.horizontalInset),
        stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
    ])
}
```

- [ ] **Step 4: Replace `viewDidAppear` + event/station selection + loading helpers**

Replace `viewDidAppear`, `onEventSelected`, `showSelectFields`, `showLoadingFields` with:

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if eventsLoaded { return }

    if changeStation {
        let course = CurrentCourse.getCurrentCourse()
        eventList.options = [course?.eventName ?? ""]
        eventList.select(course?.eventName ?? "")
        let stations = course?.dataEntryGroups as? [[String: Any]] ?? []
        aidStationOptions = stations.compactMap { $0["title"] as? String }
        aidStationField.isHidden = false
        aidStationField.isEnabled = true
        unpairedDataEntryGroups = course?.dataEntryGroups as? [Any]
        eventList.isUserInteractionEnabled = false
        eventsLoaded = true
        return
    }

    eventsLoaded = true
    loadEvents()
}

/// Fetch the live events list and populate the open selector. Shows the loading
/// state while in flight; handles error / no-events by alerting on this screen.
private func loadEvents() {
    loadingSpinner.startAnimating()
    loadingLabel.isHidden = false
    OSTBackend.shared.getAllEvents { [weak self] object, error in
        guard let self = self else { return }
        self.loadingSpinner.stopAnimating()
        self.loadingLabel.isHidden = true

        if error != nil {
            let alert = UIAlertController(title: "Error", message: "Couldn't get the events", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in self.loadEvents() })
            alert.addAction(UIAlertAction(title: "Back to Login", style: .cancel) { _ in self.dismissToLogin() })
            self.present(alert, animated: true)
            return
        }

        let data = (object as? [String: Any])?["data"] as? [Any]
        if (data?.count ?? 0) == 0 {
            AppDelegate.getInstance()?.getNetworkManager()?.addToken(toHeader: nil)
            let alert = UIAlertController(title: "No Events Available",
                message: "You are not authorized for any live events. Make sure your event is enabled for live entry and that you are authorized as a steward.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in self.dismissToLogin() })
            self.present(alert, animated: true)
            return
        }

        let pickerEvents = NSMutableArray()
        for dataObject in data ?? [] {
            if let event = EventModel.mr_import(from: dataObject, in: self.tempContext) as? EventModel {
                pickerEvents.add(event)
            }
        }
        pickerEvents.sort(using: [NSSortDescriptor(key: "startTime", ascending: false)])
        self.events = pickerEvents
        let strings = NSMutableArray()
        for case let event as EventModel in pickerEvents { if let name = event.name { strings.add(name) } }
        self.eventStrings = strings

        UserDefaults.standard.set(2, forKey: "reviewScreenPicklistValue")
        UserDefaults.standard.synchronize()

        self.eventList.options = (strings as? [String]) ?? []
        if strings.count == 1, let only = (strings as? [String])?.first {
            self.eventList.select(only) // fires onEventSelected
        }
    }
}

private func dismissToLogin() {
    dismiss(animated: true, completion: nil)
}

private func onEventSelected() {
    let eventModels = (events as? [EventModel]) ?? []
    guard let found = eventModels.first(where: { $0.name == eventList.selectedOption }) else { return }
    selectedEvent = found
    let groups = found.dataEntryGroups as? [[String: Any]] ?? []
    aidStationOptions = groups.compactMap { $0["title"] as? String }
    aidStationField.value = nil
    aidStationField.isHidden = false
    aidStationField.isEnabled = true
    nextButton.alpha = 0
}

@objc private func openAidStationPicker() {
    BottomSheetPicker.present(from: self, title: "Aid Station",
                             options: aidStationOptions, selected: aidStationField.value) { [weak self] choice in
        guard let self = self else { return }
        self.aidStationField.value = choice
        UIView.animate(withDuration: 0.3) { self.nextButton.alpha = 1 }
    }
}

private func showSelectFields() {
    eventList.isHidden = false
    aidStationField.isHidden = (selectedEvent == nil)
    nextButton.isHidden = false
    progressLabel.isHidden = true
    progressBar.isHidden = true
}

private func showLoadingFields() {
    [eventList, aidStationField, nextButton].forEach { $0.isHidden = true }
    progressLabel.isHidden = false
    progressBar.isHidden = false
}
```

Add the two new stored properties near `selectedEvent` (top of the class):
```swift
var aidStationOptions: [String] = []
```
(`unpairedDataEntryGroups`, `eventsLoaded`, `selectedEvent` already exist.)

- [ ] **Step 5: Point `onNext` at the new controls (data path otherwise unchanged)**

In `onNext`, the only changes: the station title now comes from `aidStationField.value` and the progress label from `eventList.selectedOption`. Update exactly these two reads:
- The guard: `groups.first(where: { ($0["title"] as? String) == aidStationField.value })`
- The progress text: `progressLabel.text = "Downloading \(eventList.selectedOption ?? "") Data"`

Leave the rest of `onNext` (the `changeStation` branch, the `getEventsDetails` closure and all `CurrentCourse` population) byte-for-byte as it is.

- [ ] **Step 6: Build + full suite**

Run:
```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD/TEST SUCCEEDED; existing tests still pass (DisclosureSelectFieldTests still present at this point and passing). Confirm no reference errors and that `LoginViewController` (unchanged) still compiles against `loadEventDataAndPresent`.

- [ ] **Step 7: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTEventSelectionViewController.swift"
git commit -m "feat: open event selector + aid-station drawer + loading state on event selection"
```

- [ ] **Step 8: Manual verification (human)**

Login → confirm the event screen appears immediately with a spinner + "Loading events…", then shows events as an open selector; pick an event → aid-station field enables; tap it → bottom drawer slides up; pick a station → drawer closes, "Start Tracking" appears → downloads and opens the tracker. Then Utilities → Change Station: event shown locked, aid-station drawer works, Cancel dismisses. Also verify no-events account returns to login, and dark mode.

---

### Task 4: Remove the now-unused DisclosureSelectField

**Files:**
- Delete: `OST Tracker/Swift/DesignSystem/DisclosureSelectField.swift`
- Delete: `OST TrackerTests/Swift/DisclosureSelectFieldTests.swift`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (de-register both)

**Interfaces:** none (pure removal). After Task 3 nothing references `DisclosureSelectField`.

- [ ] **Step 1: Confirm zero references**

Run:
```bash
grep -rn "DisclosureSelectField" "OST Tracker" "OST TrackerTests" | grep -v "DisclosureSelectField.swift"
```
Expected: no matches. If any appear, STOP — Task 3 is incomplete.

- [ ] **Step 2: De-register from the project, then delete the files**

The repo has an add helper; for removal use the xcodeproj gem directly (de-registers the file from all targets/groups; cascades to build files):
```bash
ruby -e 'require "xcodeproj"; p=Xcodeproj::Project.open("OST Tracker.xcodeproj"); p.files.select{|f| f.path.to_s.end_with?("DisclosureSelectField.swift") || f.path.to_s.end_with?("DisclosureSelectFieldTests.swift")}.each{|f| f.remove_from_project}; p.save'
git rm "OST Tracker/Swift/DesignSystem/DisclosureSelectField.swift" "OST TrackerTests/Swift/DisclosureSelectFieldTests.swift"
```

- [ ] **Step 3: Build + full suite**

Run:
```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: TEST SUCCEEDED; the `DisclosureSelectFieldTests` are gone and nothing else broke.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove unused DisclosureSelectField (replaced by open selector + drawer)"
```

---

## Notes for the executor
- Run the full suite once more at the end (no `-only-testing`) to confirm the branch is green.
- New design-system files live under `OST Tracker/Swift/DesignSystem/`.
- Visual/interaction verification is handed to the user; do the code/build/unit-test work autonomously first.
