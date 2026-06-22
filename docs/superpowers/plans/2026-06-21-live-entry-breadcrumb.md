# Live Entry Breadcrumb Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every non-live in-event screen a consistent one-tap `‹ Live Entry` breadcrumb in a standardized two-line header (utility row + big title), replacing the ad-hoc "Return/Go to Live Entry" bottom buttons.

**Architecture:** Add a shared `configureAsBreadcrumb` UIButton factory (mirroring the existing `configureAsMenuButton`) and a `ScreenHeader.make(...)` builder that assembles the two-line header — a utility row (`‹ Live Entry` · spacer · caller's action buttons · hamburger) over the screen's title label. All five non-live screens adopt the builder; About and Live Reads drop their pinned bottom buttons. The sync badge stays anchored to the (returned) hamburger button, so badge behavior is unchanged.

**Tech Stack:** Swift, UIKit (programmatic), XCTest. Zero third-party dependencies.

## Global Constraints

- **iOS floor 12.0** — no SF Symbols / iOS 13+ APIs at call sites without guards. All new code uses plain `UIButton`/`UILabel`/`UIStackView` + unicode glyphs (iOS 12 safe).
- **Theme-only styling** — colors/fonts/metrics come from `Theme` (`OST Tracker/Swift/DesignSystem/`); never raw `UIColor`/`UIFont` at call sites.
- **Module** `OST_Remote`; tests use `@testable import OST_Remote`.
- **All work in the worktree** created for this feature (via `superpowers:using-git-worktrees`). Never touch the main repo checkout. Confirm `git branch --show-current` before any commit.
- **Register new files** with `ruby scripts/add_file_to_xcodeproj.rb "<path>" <target>...` — source files → `"OST Remote" "OST Remote Dev"`; test files → `"OST TrackerTests"`. Idempotent; never hand-edit `project.pbxproj`. (Adding code to an already-registered file needs no registration.)
- **Test/build command** (booted sim **iPhone 17 Pro**, scheme **OST Remote Dev**):
  ```bash
  xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:"OST TrackerTests/<TestClass>"
  ```
  Build only: replace `test`/`-only-testing:...` with `build`.
- **Breadcrumb navigation target** is always `AppDelegate.getInstance()?.showTracker()` — the same call the existing bottom buttons use.
- **Scope:** the five non-live in-event screens only. Live Entry (Runner Tracker), Login, and Event Selection are untouched.
- **Visual verification** of every screen is handed to the user per the batch-autonomous-then-human-verify workflow; do not block on it.

## File Structure

- **Modify** `OST Tracker/Swift/DesignSystem/PrimaryButton.swift` — add `configureAsBreadcrumb(target:action:)` to the existing `UIButton` extension (beside `configureAsMenuButton`).
- **Create** `OST Tracker/Swift/DesignSystem/ScreenHeader.swift` — the `ScreenHeader.make(...)` two-line header builder. Register to `"OST Remote" "OST Remote Dev"`.
- **Modify** `OST TrackerTests/Swift/PrimaryButtonTests.swift` — add breadcrumb factory tests.
- **Create** `OST TrackerTests/Swift/ScreenHeaderTests.swift` — header-builder tests. Register to `"OST TrackerTests"`.
- **Modify** the five screens to adopt the builder:
  - `OST Tracker/ViewControllers/OSTCrossCheckViewController.swift`
  - `OST Tracker/ViewControllers/OSTReviewSubmitViewController.swift`
  - `OST Tracker/ViewControllers/OSTRaceOverviewViewController.swift`
  - `OST Tracker/ViewControllers/OSTLiveReadsViewController.swift` (also remove "Go to Live Entry" button)
  - `OST Tracker/ViewControllers/OSTAboutViewController.swift` (also remove "Return to Live Entry" button)

---

### Task 1: `configureAsBreadcrumb` factory

**Files:**
- Modify: `OST Tracker/Swift/DesignSystem/PrimaryButton.swift` (extend the existing `extension UIButton`)
- Test: `OST TrackerTests/Swift/PrimaryButtonTests.swift`

**Interfaces:**
- Produces: `UIButton.configureAsBreadcrumb(target: Any?, action: Selector)` — sets title `"‹ Live Entry"`, tint color, button font, leading alignment, accessibility label `"Back to Live Entry"`, and wires `action` for `.touchUpInside`.

- [ ] **Step 1: Write the failing test**

Add to `OST TrackerTests/Swift/PrimaryButtonTests.swift` (add a private spy at file scope if one is not already present):

```swift
private final class BreadcrumbActionSpy: NSObject {
    @objc func onLiveEntry() {}
}

extension PrimaryButtonTests {
    func test_breadcrumb_titleIsLiveEntryWithChevron() {
        let button = UIButton(type: .system)
        button.configureAsBreadcrumb(target: BreadcrumbActionSpy(), action: #selector(BreadcrumbActionSpy.onLiveEntry))
        XCTAssertEqual(button.title(for: .normal), "\u{2039} Live Entry")
    }

    func test_breadcrumb_hasBackAccessibilityLabel() {
        let button = UIButton(type: .system)
        button.configureAsBreadcrumb(target: BreadcrumbActionSpy(), action: #selector(BreadcrumbActionSpy.onLiveEntry))
        XCTAssertEqual(button.accessibilityLabel, "Back to Live Entry")
    }

    func test_breadcrumb_wiresTargetAction() {
        let spy = BreadcrumbActionSpy()
        let button = UIButton(type: .system)
        button.configureAsBreadcrumb(target: spy, action: #selector(BreadcrumbActionSpy.onLiveEntry))
        let actions = button.actions(forTarget: spy, forControlEvent: .touchUpInside) ?? []
        XCTAssertTrue(actions.contains("onLiveEntry"))
    }
}
```

> If `PrimaryButtonTests` is declared `final`, add these as methods inside the existing class body instead of an extension, and put `BreadcrumbActionSpy` at file scope.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/PrimaryButtonTests"
```
Expected: FAIL to compile — `value of type 'UIButton' has no member 'configureAsBreadcrumb'`.

- [ ] **Step 3: Implement the factory**

In `OST Tracker/Swift/DesignSystem/PrimaryButton.swift`, inside the existing `extension UIButton { ... }`, directly below `configureAsMenuButton`, add:

```swift
    /// Style this button as the leading "‹ Live Entry" breadcrumb shown in every
    /// non-live screen's header utility row — one tap back to bib entry. Mirrors
    /// `configureAsMenuButton` so the affordance is identical on every screen.
    func configureAsBreadcrumb(target: Any?, action: Selector) {
        setTitle("\u{2039} Live Entry", for: .normal)   // ‹ Live Entry
        setTitleColor(Theme.tint, for: .normal)
        titleLabel?.font = Theme.Font.button
        contentHorizontalAlignment = .leading
        accessibilityLabel = "Back to Live Entry"
        addTarget(target, action: action, for: .touchUpInside)
    }
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/PrimaryButtonTests"
```
Expected: PASS (all three new tests + existing ones).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/PrimaryButton.swift" "OST TrackerTests/Swift/PrimaryButtonTests.swift"
git commit -m "feat(designsystem): configureAsBreadcrumb '‹ Live Entry' button factory

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `ScreenHeader.make` two-line header builder

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/ScreenHeader.swift`
- Test: Create `OST TrackerTests/Swift/ScreenHeaderTests.swift`

**Interfaces:**
- Consumes: `UIButton.configureAsBreadcrumb` (Task 1) and the existing `UIButton.configureAsMenuButton`.
- Produces:
  ```swift
  enum ScreenHeader {
      static func make(titleLabel: UILabel,
                       trailingActions: [UIView] = [],
                       target: Any?,
                       onLiveEntry: Selector,
                       onMenu: Selector) -> (header: UIStackView, menuButton: UIButton)
  }
  ```
  Returns a vertical stack `[utilityRow, titleLabel]`. The utility row is horizontal: `[breadcrumb, spacer, <trailingActions…>, menuButton]`. The builder sets `titleLabel.font = Theme.Font.title` and `titleLabel.textColor = Theme.label` but never sets its text (caller owns the text). The returned `menuButton` is the hamburger, for sync-badge anchoring.

- [ ] **Step 1: Write the failing test**

Create `OST TrackerTests/Swift/ScreenHeaderTests.swift`:

```swift
import XCTest
@testable import OST_Remote

private final class HeaderActionSpy: NSObject {
    @objc func onLiveEntry() {}
    @objc func onMenu() {}
}

final class ScreenHeaderTests: XCTestCase {

    private func make(trailing: [UIView] = []) -> (header: UIStackView, menuButton: UIButton, title: UILabel, spy: HeaderActionSpy) {
        let title = UILabel()
        title.text = "Cross Check"
        let spy = HeaderActionSpy()
        let result = ScreenHeader.make(titleLabel: title,
                                       trailingActions: trailing,
                                       target: spy,
                                       onLiveEntry: #selector(HeaderActionSpy.onLiveEntry),
                                       onMenu: #selector(HeaderActionSpy.onMenu))
        return (result.header, result.menuButton, title, spy)
    }

    func test_header_isVerticalUtilityRowOverTitle() {
        let (header, _, title, _) = make()
        XCTAssertEqual(header.axis, .vertical)
        XCTAssertEqual(header.arrangedSubviews.count, 2)
        XCTAssertTrue(header.arrangedSubviews[0] is UIStackView)   // utility row
        XCTAssertTrue(header.arrangedSubviews[1] === title)        // title on its own line
    }

    func test_title_usesStandardTitleFont() {
        let (_, _, title, _) = make()
        XCTAssertEqual(title.font, Theme.Font.title)
    }

    func test_utilityRow_startsWithBreadcrumb_endsWithMenu() {
        let (header, menu, _, _) = make()
        let row = header.arrangedSubviews[0] as! UIStackView
        let first = row.arrangedSubviews.first as? UIButton
        XCTAssertEqual(first?.title(for: .normal), "\u{2039} Live Entry")
        XCTAssertTrue(row.arrangedSubviews.last === menu)
        XCTAssertEqual(menu.accessibilityLabel, "Menu")
    }

    func test_trailingActions_appearBeforeMenu() {
        let action = UIButton(type: .system)
        let (header, menu, _, _) = make(trailing: [action])
        let row = header.arrangedSubviews[0] as! UIStackView
        let menuIndex = row.arrangedSubviews.firstIndex(where: { $0 === menu })!
        let actionIndex = row.arrangedSubviews.firstIndex(where: { $0 === action })!
        XCTAssertLessThan(actionIndex, menuIndex)
        XCTAssertGreaterThan(actionIndex, 0) // after the breadcrumb/spacer, not first
    }

    func test_breadcrumb_wiredToTarget() {
        let (header, _, _, spy) = make()
        let row = header.arrangedSubviews[0] as! UIStackView
        let crumb = row.arrangedSubviews.first as! UIButton
        let actions = crumb.actions(forTarget: spy, forControlEvent: .touchUpInside) ?? []
        XCTAssertTrue(actions.contains("onLiveEntry"))
    }
}
```

- [ ] **Step 2: Register the test file and run to verify it fails**

```bash
ruby scripts/add_file_to_xcodeproj.rb "OST TrackerTests/Swift/ScreenHeaderTests.swift" "OST TrackerTests"
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/ScreenHeaderTests"
```
Expected: FAIL to compile — `cannot find 'ScreenHeader' in scope`.

- [ ] **Step 3: Implement the builder**

Create `OST Tracker/Swift/DesignSystem/ScreenHeader.swift`:

```swift
import UIKit

/// Builds the standard two-line screen header shared by every non-live screen:
/// a utility row (`‹ Live Entry` breadcrumb · spacer · caller's action buttons ·
/// hamburger) over the screen's title on its own line. Keeps the breadcrumb,
/// title font, and hamburger identical everywhere (DRY), and returns the
/// hamburger so the base VC can keep anchoring its sync badge to it.
enum ScreenHeader {
    static func make(titleLabel: UILabel,
                     trailingActions: [UIView] = [],
                     target: Any?,
                     onLiveEntry: Selector,
                     onMenu: Selector) -> (header: UIStackView, menuButton: UIButton) {
        titleLabel.font = Theme.Font.title
        titleLabel.textColor = Theme.label

        let breadcrumb = UIButton(type: .system)
        breadcrumb.configureAsBreadcrumb(target: target, action: onLiveEntry)

        let menuButton = UIButton(type: .system)
        menuButton.configureAsMenuButton(target: target, action: onMenu)

        let utilityRow = UIStackView(arrangedSubviews: [breadcrumb, UIView()] + trailingActions + [menuButton])
        utilityRow.axis = .horizontal
        utilityRow.alignment = .center
        utilityRow.spacing = 12

        let header = UIStackView(arrangedSubviews: [utilityRow, titleLabel])
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = 4

        return (header, menuButton)
    }
}
```

- [ ] **Step 4: Register the source file and run the test to verify it passes**

```bash
ruby scripts/add_file_to_xcodeproj.rb "OST Tracker/Swift/DesignSystem/ScreenHeader.swift" "OST Remote" "OST Remote Dev"
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/ScreenHeaderTests"
```
Expected: PASS (all five tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/ScreenHeader.swift" "OST TrackerTests/Swift/ScreenHeaderTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat(designsystem): ScreenHeader two-line header builder

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Adopt the header in Cross Check

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTCrossCheckViewController.swift`

**Interfaces:**
- Consumes: `ScreenHeader.make` (Task 2). Cross Check has no trailing header actions (`trailingActions: []`), menu selector `onMenu` (exists), and needs a new `onLiveEntry` handler.

- [ ] **Step 1: Add the breadcrumb handler**

In `OSTCrossCheckViewController.swift`, in the `// MARK: - Navigation` / actions area (near `onMenu`/`onReview`), add:

```swift
    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
    }
```

- [ ] **Step 2: Replace the hand-rolled header with the builder**

In `buildUI()`, replace these lines:

```swift
        titleLabel.text = "Cross Check"
        titleLabel.font = Theme.Font.brand
        titleLabel.textColor = Theme.label

        subtitleLabel.font = Theme.Font.field
        subtitleLabel.textColor = Theme.secondaryLabel

        menuBtn.configureAsMenuButton(target: self, action: #selector(onMenu))
```

with:

```swift
        titleLabel.text = "Cross Check"

        subtitleLabel.font = Theme.Font.field
        subtitleLabel.textColor = Theme.secondaryLabel

        let header = ScreenHeader.make(titleLabel: titleLabel,
                                       target: self,
                                       onLiveEntry: #selector(onLiveEntry),
                                       onMenu: #selector(onMenu))
        menuButton = header.menuButton
```

Then replace the old `headerRow` construction:

```swift
        let headerRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), menuBtn])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12
```

with (use the builder's `header` stack in `topStack`):

```swift
        // header (utility row + title) supplied by ScreenHeader.make above
```

Update the `topStack` line from `[headerRow, subtitleLabel, inOutControl]` to `[header.header, subtitleLabel, inOutControl]`.

In the badge constraints, change both references from `menuBtn` to `header.menuButton`:

```swift
            badgeView.topAnchor.constraint(equalTo: header.menuButton.topAnchor, constant: -4),
            badgeView.leadingAnchor.constraint(equalTo: header.menuButton.trailingAnchor, constant: -14),
```

- [ ] **Step 3: Remove the now-unused `menuBtn` property and stale `menuButton`/title assignments**

- Delete the `private let menuBtn = UIButton(...)` property declaration.
- In `viewDidLoad`, delete the line `menuButton = menuBtn` (the assignment now happens in `buildUI`). Keep `badgeLabel = badgeView`.

> If a compiler error reports `menuBtn` still referenced anywhere else, replace that reference with `header.menuButton` (in-scope only within `buildUI`); otherwise the property is fully removed.

- [ ] **Step 4: Build and run Cross Check's test suite**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/CrossCheckPresentationTests"
```
Expected: PASS (build succeeds; presentation tests still green). Also confirm `ScreenHeaderTests` and `PrimaryButtonTests` remain green if run.

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTCrossCheckViewController.swift"
git commit -m "refactor(crosscheck): adopt ScreenHeader breadcrumb header

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Adopt the header in Review/Sync

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTReviewSubmitViewController.swift`

**Interfaces:**
- Consumes: `ScreenHeader.make`. Trailing action: `[exportButton]`. Menu selector here is `onRightMenu` (not `onMenu`). Title text is set dynamically elsewhere (event/course name) and must keep working — pass the existing `titleLabel`.

- [ ] **Step 1: Add the breadcrumb handler**

Near the existing actions, add:

```swift
    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
    }
```

- [ ] **Step 2: Replace the header construction**

In `buildUI()`, replace:

```swift
        titleLabel.font = Theme.Font.brand
        titleLabel.textColor = Theme.label
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        menuBtn.setTitle("Menu \u{2630}", for: .normal) // ☰ — opens the right-side drawer
        menuBtn.setTitleColor(Theme.tint, for: .normal)
        menuBtn.titleLabel?.font = Theme.Font.button
        menuBtn.addTarget(self, action: #selector(onRightMenu), for: .touchUpInside)
```

with:

```swift
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
```

(`titleLabel` font/color are now set by the builder; the custom `menuBtn` is replaced by the builder's hamburger.)

Keep the `exportButton` configuration block as-is. Then replace:

```swift
        // Title leading; Export + Menu on the trailing edge (the hamburger opens the
        // right-side drawer), matching the other screens' header convention.
        let headerRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), exportButton, menuBtn])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12
```

with:

```swift
        let header = ScreenHeader.make(titleLabel: titleLabel,
                                       trailingActions: [exportButton],
                                       target: self,
                                       onLiveEntry: #selector(onLiveEntry),
                                       onMenu: #selector(onRightMenu))
        menuButton = header.menuButton
```

Update the badge constraints to anchor to `header.menuButton`:

```swift
            badgeView.topAnchor.constraint(equalTo: header.menuButton.topAnchor, constant: -4),
            badgeView.leadingAnchor.constraint(equalTo: header.menuButton.trailingAnchor, constant: -14),
```

> Note: the original Review/Sync badge constraints may not exist as a separate block — search for the `badgeView.topAnchor`/`leadingAnchor` constraints (they reference `menuBtn`) and repoint them to `header.menuButton`.

Update the `topStack` line from `[headerRow, sortButton]` to `[header.header, sortButton]`.

- [ ] **Step 3: Remove the unused `menuBtn` property and stale assignment**

- Delete the `private let menuBtn = ...` property.
- In `viewDidLoad`, delete `menuButton = menuBtn` (now set in `buildUI`); keep `badgeLabel = badgeView`.

- [ ] **Step 4: Build and run Review's test suite**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/ReviewPresentationTests"
```
Expected: PASS (build succeeds; suite green).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTReviewSubmitViewController.swift"
git commit -m "refactor(review): adopt ScreenHeader breadcrumb header (export stays trailing)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Adopt the header in Race Overview

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTRaceOverviewViewController.swift`

**Interfaces:**
- Consumes: `ScreenHeader.make`. Trailing action: `[refresh]`. Menu selector `onMenu` (exists). Title static "Race Overview".

- [ ] **Step 1: Add the breadcrumb handler**

Near the actions (by `onRefresh`/`onMenu`), add:

```swift
    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
    }
```

- [ ] **Step 2: Replace the header construction**

In `buildUI()`, the `refresh` button block stays as-is. Replace:

```swift
        titleLabel.text = "Race Overview"
        titleLabel.font = Theme.Font.title
        titleLabel.textColor = Theme.label
```

with:

```swift
        titleLabel.text = "Race Overview"
```

Then replace:

```swift
        let menuBtn = UIButton(type: .system)
        menuBtn.configureAsMenuButton(target: self, action: #selector(onMenu))
        menuButton = menuBtn // base VC anchors the sync badge to this

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), refresh, menuBtn])
        titleRow.alignment = .center
        titleRow.spacing = 16
```

with:

```swift
        let header = ScreenHeader.make(titleLabel: titleLabel,
                                       trailingActions: [refresh],
                                       target: self,
                                       onLiveEntry: #selector(onLiveEntry),
                                       onMenu: #selector(onMenu))
        menuButton = header.menuButton // base VC anchors the sync badge to this
```

Update the `controls` stack first element from `titleRow` to `header.header`:

```swift
        let controls = UIStackView(arrangedSubviews: [header.header, eventList, modeControl,
                                                       searchField, stationButton, infoLabel])
```

> Race Overview has no separate `badgeView`/badge constraints in `buildUI` (the base VC handles badge positioning via `ostPositionBadgeAtMenu` against `menuButton`). No badge-constraint edits needed here.

- [ ] **Step 3: Build and run Race Overview's test suite**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/RaceOverviewTests"
```
Expected: PASS (build succeeds; suite green).

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTRaceOverviewViewController.swift"
git commit -m "refactor(raceoverview): adopt ScreenHeader breadcrumb header (refresh stays trailing)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Adopt the header in Live Reads + remove "Go to Live Entry" button

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTLiveReadsViewController.swift`

**Interfaces:**
- Consumes: `ScreenHeader.make`. Trailing action: `[refresh]`. Menu selector `onMenu` (exists). The live/updated status line (`statusStack`) stays, appended below the builder's header inside the tinted header pane. The pinned `goLive` PrimaryButton is removed (the breadcrumb replaces it).

- [ ] **Step 1: Add/rename the breadcrumb handler**

The screen has `@objc private func onGoToLiveEntry() { AppDelegate.getInstance()?.showTracker() }`. Rename it to `onLiveEntry` for consistency:

```swift
    @objc private func onLiveEntry() { AppDelegate.getInstance()?.showTracker() }
```

(If any other reference to `onGoToLiveEntry` remains, update it.)

- [ ] **Step 2: Replace the header construction and drop `goLive`**

In `buildUI()`, the `refresh` button block stays. Replace:

```swift
        titleLabel.font = Theme.Font.button
        titleLabel.textColor = Theme.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
```

with:

```swift
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
```

Delete the `goLive` button block entirely:

```swift
        let menuBtn = UIButton(type: .system)
        menuBtn.configureAsMenuButton(target: self, action: #selector(onMenu))
        menuButton = menuBtn // base VC anchors the sync badge to this

        let goLive = PrimaryButton(title: "Go to Live Entry", role: .primary)
        goLive.translatesAutoresizingMaskIntoConstraints = false
        goLive.addTarget(self, action: #selector(onGoToLiveEntry), for: .touchUpInside)

        // Title + controls on top, live/updated status on its own line below —
        // they don't both fit on one row at phone width.
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), refresh, menuBtn])
        titleRow.alignment = .center
        titleRow.spacing = 12

        let statusStack = UIStackView(arrangedSubviews: [liveDot, updatedLabel, UIView()])
        statusStack.alignment = .center
        statusStack.spacing = 6

        let headerStack = UIStackView(arrangedSubviews: [titleRow, statusStack])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .fill
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)
```

with:

```swift
        let screen = ScreenHeader.make(titleLabel: titleLabel,
                                       trailingActions: [refresh],
                                       target: self,
                                       onLiveEntry: #selector(onLiveEntry),
                                       onMenu: #selector(onMenu))
        menuButton = screen.menuButton // base VC anchors the sync badge to this

        let statusStack = UIStackView(arrangedSubviews: [liveDot, updatedLabel, UIView()])
        statusStack.alignment = .center
        statusStack.spacing = 6

        let headerStack = UIStackView(arrangedSubviews: [screen.header, statusStack])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .fill
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)
```

- [ ] **Step 3: Update the header-pane constraints (remove fixed height, drop `goLive`)**

Remove `view.addSubview(goLive)` (search and delete it).

In the `NSLayoutConstraint.activate([...])` block, delete:

```swift
            header.heightAnchor.constraint(equalToConstant: 68),
```

and change the header-stack vertical pinning from center to top/bottom padding so the taller (three-line) content fits:

Replace:

```swift
            headerStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),
```

with:

```swift
            headerStack.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
            headerStack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),
```

Change the tableView bottom from `goLive.topAnchor` to the safe-area bottom, and delete the `goLive` constraints:

Replace:

```swift
            tableView.bottomAnchor.constraint(equalTo: goLive.topAnchor, constant: -8),

            goLive.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Metric.horizontalInset),
            goLive.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Metric.horizontalInset),
            goLive.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
```

with:

```swift
            tableView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
```

- [ ] **Step 4: Build and run the Live Reads-related suites**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:"OST TrackerTests/LiveReadsFormatTests" \
  -only-testing:"OST TrackerTests/LiveReadsMergeTests"
```
Expected: PASS (these are logic suites; the gate here is that the project **builds** with the header changes and existing Live Reads logic stays green). If the build fails, fix references (most likely a lingering `goLive` or `onGoToLiveEntry`).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTLiveReadsViewController.swift"
git commit -m "refactor(livereads): adopt ScreenHeader breadcrumb; drop pinned 'Go to Live Entry'

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Adopt the header in About + remove "Return to Live Entry" button

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTAboutViewController.swift`

**Interfaces:**
- Consumes: `ScreenHeader.make`. No trailing actions. Menu selector `onMenu` (exists, `@IBAction`). The pinned `returnButton` PrimaryButton is removed.

- [ ] **Step 1: Rename the breadcrumb handler**

Replace:

```swift
    @IBAction func onReturnToLiveEntry(_ sender: Any) {
        AppDelegate.getInstance()?.showTracker()
    }
```

with:

```swift
    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
    }
```

- [ ] **Step 2: Remove the `returnButton` property**

Delete:

```swift
    private let returnButton = PrimaryButton(title: "Return to Live Entry", role: .primary)
```

- [ ] **Step 3: Replace the header construction**

In `buildUI()`, replace:

```swift
        menuBtn.configureAsMenuButton(target: self, action: #selector(onMenu))

        let headerRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), menuBtn])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12
```

with:

```swift
        let header = ScreenHeader.make(titleLabel: titleLabel,
                                       target: self,
                                       onLiveEntry: #selector(onLiveEntry),
                                       onMenu: #selector(onMenu))
        menuButton = header.menuButton
```

> `titleLabel.font = Theme.Font.brand` is currently set earlier in `buildUI`; the builder overrides it to `Theme.Font.title`. Leave the existing `titleLabel.text = "About"` line; you may delete the now-redundant `titleLabel.font`/`textColor` lines if present.

- [ ] **Step 4: Drop `returnButton` from layout**

Change:

```swift
        returnButton.addTarget(self, action: #selector(onReturnToLiveEntry), for: .touchUpInside)

        for v in [headerRow, contentStack, returnButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
```

to:

```swift
        for v in [header.header, contentStack] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
```

In the constraints block, change all `headerRow` references to `header.header`, and delete the `returnButton` constraints:

```swift
            returnButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            returnButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),
            returnButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
            returnButton.topAnchor.constraint(greaterThanOrEqualTo: contentStack.bottomAnchor, constant: 24),
```

Also update the badge constraints to anchor to `header.menuButton`:

```swift
            badgeView.topAnchor.constraint(equalTo: header.menuButton.topAnchor, constant: -4),
            badgeView.leadingAnchor.constraint(equalTo: header.menuButton.trailingAnchor, constant: -14),
```

And in `viewDidLoad`, change `menuButton = menuBtn` (delete it — now set in `buildUI`) while keeping `badgeLabel = badgeView`. Delete the `private let menuBtn = UIButton(type: .system)` property.

> Removing `returnButton` leaves `contentStack` pinned by its existing `centerY` + `top >= headerRow.bottom + 24` constraints, which remain valid.

- [ ] **Step 5: Build the project**

```bash
xcodebuild build -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED. (No dedicated About test suite; the gate is a clean build with no lingering `returnButton`/`menuBtn`/`onReturnToLiveEntry` references.)

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTAboutViewController.swift"
git commit -m "refactor(about): adopt ScreenHeader breadcrumb; drop pinned 'Return to Live Entry'

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Full regression + final verification

**Files:** none (verification only).

- [ ] **Step 1: Run the full test target**

```bash
xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED, all suites PASS (notably `PrimaryButtonTests`, `ScreenHeaderTests`, `CrossCheckPresentationTests`, `ReviewPresentationTests`, `RaceOverviewTests`).

- [ ] **Step 2: Confirm no orphaned references**

```bash
grep -rn "Return to Live Entry\|Go to Live Entry\|onReturnToLiveEntry\|onGoToLiveEntry" "OST Tracker"
```
Expected: no matches.

- [ ] **Step 3: Hand off for visual verification**

Summarize for the user that all five non-live screens now show the `‹ Live Entry` breadcrumb in a two-line header, the two pinned bottom buttons are gone, and the sync badge still sits on the hamburger. Ask the user to visually verify each screen in the simulator (per the batch-autonomous-then-human-verify workflow).

---

## Self-Review

**Spec coverage:**
- Consistent affordance on all five non-live screens → Tasks 3–7. ✓
- Shared `configureAsBreadcrumb` factory → Task 1. ✓
- Shared two-line header builder returning the menu button for badge anchoring → Task 2. ✓
- Breadcrumb calls `showTracker()` → handler added in every adoption task. ✓
- Remove About + Live Reads pinned bottom buttons → Tasks 6, 7. ✓
- Standardize title font (`Theme.Font.title`) → builder sets it (Task 2), adoption tasks drop per-screen fonts. ✓
- Sync badge unchanged, anchored to hamburger → Tasks 3, 4, 7 repoint badge constraints to `header.menuButton`; Task 5 relies on base-VC positioning. ✓
- Tests follow existing patterns → Tasks 1, 2. ✓
- Out of scope (Live Entry, Login, Event Selection) untouched → no tasks touch them. ✓

**Placeholder scan:** No TBD/TODO; every code step shows concrete before/after. ✓

**Type consistency:** `ScreenHeader.make(titleLabel:trailingActions:target:onLiveEntry:onMenu:) -> (header: UIStackView, menuButton: UIButton)` used identically in Tasks 2–7. The returned tuple member `.header` is consumed as the header stack and `.menuButton` for badge/`menuButton` assignment everywhere. Breadcrumb handler named `onLiveEntry` consistently across all five screens. ✓
