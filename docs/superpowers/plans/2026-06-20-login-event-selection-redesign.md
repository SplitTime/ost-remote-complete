# Login & Event-Selection Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a light-default design-system layer and apply it to the Login (restyle) and Event-Selection (XIB-retiring rewrite with inline-expand pickers) screens, plus a Utilities appearance toggle.

**Architecture:** A dependency-free `Theme` (semantic color roles + metrics + fonts) where iOS 13+ roles are dynamic `UIColor`s and iOS 12 resolves to light. Reusable `PrimaryButton`, `StyledTextField`, `DisclosureSelectField` components draw only from `Theme`. The two screens consume the components; an `AppearanceController` persists a *System · Light · Dark* choice and applies it via the window on iOS 13+.

**Tech Stack:** Swift + UIKit, XCTest. No third-party dependencies. Build/test from `OST Tracker.xcodeproj` (no workspace, no CocoaPods).

## Global Constraints

- **iOS floor: 12.0.** All dark-mode APIs (`UIColor(dynamicProvider:)`, `overrideUserInterfaceStyle`, `UIUserInterfaceStyle`) MUST be guarded with `#available(iOS 13.0, *)` / `@available`. iOS 12 resolves to **light** with no branching at call sites.
- **No raw colors at call sites.** Screens and components reference `Theme.<role>` only — never a literal `UIColor(red:…)`.
- **Module name is `OST_Remote`** — tests use `@testable import OST_Remote`.
- **New files must be added to targets.** Every new `.swift` file under `OST Tracker/` must be added to the **OST Remote** and **OST Remote Dev** targets in `OST Tracker.xcodeproj/project.pbxproj`; every new test file must be added to the **OST TrackerTests** target. A file not in its target silently won't compile.
- **Test command** (adjust the simulator name to one installed locally; the test target builds under the `OST Remote Dev` scheme):
  ```bash
  xcodebuild test -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    -only-testing:"OST TrackerTests/<TestClass>"
  ```
- **Preserve public API.** `OSTEventSelectionViewController` keeps its `@objc(OSTEventSelectionViewController)` name and its `@objc` members `changeStation`, `tempContext`, `events`, `eventStrings`, and `class func loadEventDataAndPresent(from:completion:)`. Both callers (`LoginViewController`, `OSTUtilitiesViewController.onChangeStation`) stay untouched.
- **Style preference:** plain, self-describing names; functional and DRY.

---

### Task 1: Theme (color roles, metrics, fonts)

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/Theme.swift`
- Test: `OST TrackerTests/Swift/ThemeTests.swift`

**Interfaces:**
- Produces:
  - `enum Theme` with static `UIColor` role properties: `background`, `secondaryBackground`, `fieldFill`, `separator`, `label`, `secondaryLabel`, `tint`, `success`, `destructive`.
  - `static func dynamic(light: UIColor, dark: UIColor) -> UIColor`
  - `enum Theme.Metric { static let cornerRadius: CGFloat = 10; fieldHeight = 48; buttonHeight = 52; horizontalInset = 28 }`
  - `enum Theme.Font { static let title, field, button, caption: UIFont }`

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/ThemeTests.swift
import XCTest
@testable import OST_Remote

final class ThemeTests: XCTestCase {
    func test_dynamic_resolvesByTrait_oniOS13() {
        guard #available(iOS 13.0, *) else { return }
        let c = Theme.dynamic(light: .red, dark: .blue)
        XCTAssertEqual(c.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)), .red)
        XCTAssertEqual(c.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)), .blue)
    }

    func test_roles_lightAndDarkDiffer_oniOS13() {
        guard #available(iOS 13.0, *) else { return }
        let light = Theme.background.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = Theme.background.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertNotEqual(light, dark, "background must differ between light and dark")
    }

    func test_metrics_haveExpectedValues() {
        XCTAssertEqual(Theme.Metric.cornerRadius, 10)
        XCTAssertEqual(Theme.Metric.fieldHeight, 48)
        XCTAssertEqual(Theme.Metric.buttonHeight, 52)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command with `-only-testing:"OST TrackerTests/ThemeTests"`.
Expected: FAIL — `Theme` is undefined / does not compile.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/Theme.swift
import UIKit

/// Semantic, theme-aware colors plus shared metrics and fonts. Screens and
/// components reference roles here — never raw colors. On iOS 13+ each role is a
/// dynamic UIColor that follows the trait collection; on iOS 12 it resolves to the
/// light value (the dynamic initializer does not exist there), so call sites are
/// identical on every OS version.
enum Theme {

    // MARK: Color roles
    static var background: UIColor { dynamic(light: Palette.lightBackground, dark: Palette.darkBackground) }
    static var secondaryBackground: UIColor { dynamic(light: Palette.lightSecondaryBackground, dark: Palette.darkSecondaryBackground) }
    static var fieldFill: UIColor { dynamic(light: Palette.lightFieldFill, dark: Palette.darkFieldFill) }
    static var separator: UIColor { dynamic(light: Palette.lightSeparator, dark: Palette.darkSeparator) }
    static var label: UIColor { dynamic(light: Palette.lightLabel, dark: Palette.darkLabel) }
    static var secondaryLabel: UIColor { dynamic(light: Palette.lightSecondaryLabel, dark: Palette.darkSecondaryLabel) }
    static var tint: UIColor { dynamic(light: Palette.lightTint, dark: Palette.darkTint) }
    static var success: UIColor { dynamic(light: Palette.lightSuccess, dark: Palette.darkSuccess) }
    static var destructive: UIColor { dynamic(light: Palette.lightDestructive, dark: Palette.darkDestructive) }

    // MARK: Metrics
    enum Metric {
        static let cornerRadius: CGFloat = 10
        static let fieldHeight: CGFloat = 48
        static let buttonHeight: CGFloat = 52
        static let horizontalInset: CGFloat = 28
    }

    // MARK: Fonts
    enum Font {
        static let title = UIFont.systemFont(ofSize: 30, weight: .bold)
        static let field = UIFont.systemFont(ofSize: 17)
        static let button = UIFont.systemFont(ofSize: 18, weight: .semibold)
        static let caption = UIFont.systemFont(ofSize: 12, weight: .semibold)
    }

    // MARK: Dynamic resolver
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
        }
        return light
    }
}

/// Raw palette values. Internal (not private) so tests can reference them.
enum Palette {
    static let lightBackground          = UIColor(white: 0.95, alpha: 1)           // systemGroupedBackground-ish
    static let darkBackground           = UIColor.black
    static let lightSecondaryBackground = UIColor.white
    static let darkSecondaryBackground  = UIColor(white: 0.11, alpha: 1)
    static let lightFieldFill           = UIColor.white
    static let darkFieldFill            = UIColor(white: 0.11, alpha: 1)
    static let lightSeparator           = UIColor(white: 0.90, alpha: 1)
    static let darkSeparator            = UIColor(white: 0.17, alpha: 1)
    static let lightLabel               = UIColor(white: 0.11, alpha: 1)
    static let darkLabel                = UIColor.white
    static let lightSecondaryLabel      = UIColor(white: 0.56, alpha: 1)
    static let darkSecondaryLabel       = UIColor(white: 0.56, alpha: 1)
    static let lightTint                = UIColor(red: 0/255,  green: 122/255, blue: 255/255, alpha: 1) // systemBlue
    static let darkTint                 = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
    static let lightSuccess             = UIColor(red: 52/255, green: 199/255, blue: 89/255,  alpha: 1) // systemGreen
    static let darkSuccess              = UIColor(red: 48/255, green: 209/255, blue: 88/255,  alpha: 1)
    static let lightDestructive         = UIColor(red: 255/255, green: 59/255, blue: 48/255,  alpha: 1) // systemRed
    static let darkDestructive          = UIColor(red: 255/255, green: 69/255, blue: 58/255,  alpha: 1)
}
```

Add `Theme.swift` to the **OST Remote** and **OST Remote Dev** targets in `project.pbxproj`; add `ThemeTests.swift` to **OST TrackerTests**.

- [ ] **Step 4: Run test to verify it passes**

Run the test command with `-only-testing:"OST TrackerTests/ThemeTests"`.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/Theme.swift" "OST TrackerTests/Swift/ThemeTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add Theme design-system layer (roles, metrics, fonts)"
```

---

### Task 2: AppearanceController (+ launch apply)

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/AppearanceController.swift`
- Modify: `OST Tracker/AppDelegate.m` (call `apply` after `makeKeyAndVisible`)
- Test: `OST TrackerTests/Swift/AppearanceControllerTests.swift`

**Interfaces:**
- Produces:
  - `@objc enum AppearanceMode: Int { case system, light, dark }`
  - `@objc final class AppearanceController: NSObject` with `@objc static let shared`, `init(defaults: UserDefaults = .standard)`, `@objc var mode: AppearanceMode { get set }`, `@objc func apply()`, and (iOS 13+) `var interfaceStyle: UIUserInterfaceStyle`.

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/AppearanceControllerTests.swift
import XCTest
@testable import OST_Remote

final class AppearanceControllerTests: XCTestCase {
    private func freshDefaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func test_defaultMode_isSystem() {
        let sut = AppearanceController(defaults: freshDefaults("ap.default"))
        XCTAssertEqual(sut.mode, .system)
    }

    func test_modePersistsAcrossInstances() {
        let d = freshDefaults("ap.persist")
        AppearanceController(defaults: d).mode = .dark
        XCTAssertEqual(AppearanceController(defaults: d).mode, .dark)
    }

    func test_interfaceStyleMapping_oniOS13() {
        guard #available(iOS 13.0, *) else { return }
        let sut = AppearanceController(defaults: freshDefaults("ap.style"))
        sut.mode = .light;  XCTAssertEqual(sut.interfaceStyle, .light)
        sut.mode = .dark;   XCTAssertEqual(sut.interfaceStyle, .dark)
        sut.mode = .system; XCTAssertEqual(sut.interfaceStyle, .unspecified)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:"OST TrackerTests/AppearanceControllerTests"`.
Expected: FAIL — `AppearanceController` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/AppearanceController.swift
import UIKit

@objc enum AppearanceMode: Int {
    case system = 0   // raw 0 so UserDefaults' default (absent key → 0) means System
    case light  = 1
    case dark   = 2
}

/// Persists the user's appearance choice and applies it to the app window on
/// iOS 13+. No-op on iOS 12 (there is no theme to switch to).
@objc final class AppearanceController: NSObject {
    @objc static let shared = AppearanceController()

    private let key = "appearanceMode"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    @objc var mode: AppearanceMode {
        get { AppearanceMode(rawValue: defaults.integer(forKey: key)) ?? .system }
        set { defaults.set(newValue.rawValue, forKey: key); apply() }
    }

    @available(iOS 13.0, *)
    var interfaceStyle: UIUserInterfaceStyle {
        switch mode {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    @objc func apply() {
        guard #available(iOS 13.0, *) else { return }
        AppDelegate.getInstance()?.window?.overrideUserInterfaceStyle = interfaceStyle
    }
}
```

- [ ] **Step 4: Wire launch apply in AppDelegate**

In `OST Tracker/AppDelegate.m`, immediately after the existing `[self.window makeKeyAndVisible];` (around line 73), add:

```objc
[[AppearanceController shared] apply];
```

Ensure the Swift bridging header is imported near the top of `AppDelegate.m` (it already imports `"OST Remote-Swift.h"` for other Swift classes; if not present, add `#import "OST Remote-Swift.h"`).

- [ ] **Step 5: Run test to verify it passes**

Run with `-only-testing:"OST TrackerTests/AppearanceControllerTests"`.
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/AppearanceController.swift" "OST Tracker/AppDelegate.m" "OST TrackerTests/Swift/AppearanceControllerTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add AppearanceController (persist + apply theme; launch wiring)"
```

---

### Task 3: PrimaryButton

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/PrimaryButton.swift`
- Test: `OST TrackerTests/Swift/PrimaryButtonTests.swift`

**Interfaces:**
- Produces: `final class PrimaryButton: UIButton` with `init(title: String, role: PrimaryButton.Role = .primary)` and `enum Role { case primary, success }`. `.primary` fills with `Theme.tint`; `.success` fills with `Theme.success`. White title, `Theme.Font.button`, corner radius `Theme.Metric.cornerRadius`, height `Theme.Metric.buttonHeight`.

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/PrimaryButtonTests.swift
import XCTest
@testable import OST_Remote

final class PrimaryButtonTests: XCTestCase {
    func test_setsTitleAndCornerRadius() {
        let b = PrimaryButton(title: "Log In")
        XCTAssertEqual(b.title(for: .normal), "Log In")
        XCTAssertEqual(b.layer.cornerRadius, Theme.Metric.cornerRadius)
    }

    func test_heightConstraintMatchesMetric() {
        let b = PrimaryButton(title: "Go")
        let h = b.constraints.first { $0.firstAttribute == .height }
        XCTAssertEqual(h?.constant, Theme.Metric.buttonHeight)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:"OST TrackerTests/PrimaryButtonTests"`.
Expected: FAIL — `PrimaryButton` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/PrimaryButton.swift
import UIKit

/// Filled, theme-styled action button. `.primary` uses the brand tint;
/// `.success` uses the green confirm color (e.g. "Start Tracking").
final class PrimaryButton: UIButton {
    enum Role { case primary, success }

    init(title: String, role: Role = .primary) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = Theme.Font.button
        setTitleColor(.white, for: .normal)
        backgroundColor = (role == .success) ? Theme.success : Theme.tint
        layer.cornerRadius = Theme.Metric.cornerRadius
        heightAnchor.constraint(equalToConstant: Theme.Metric.buttonHeight).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run with `-only-testing:"OST TrackerTests/PrimaryButtonTests"`.
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/PrimaryButton.swift" "OST TrackerTests/Swift/PrimaryButtonTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add PrimaryButton component"
```

---

### Task 4: StyledTextField

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/StyledTextField.swift`
- Test: `OST TrackerTests/Swift/StyledTextFieldTests.swift`

**Interfaces:**
- Produces: `final class StyledTextField: UITextField` with `init(placeholder: String, secure: Bool)`. Sets `Theme.fieldFill` background, `Theme.Font.field`, no autocapitalization/autocorrection, `textContentType` (`.password` when secure else `.username`), `isSecureTextEntry = secure`, corner radius `Theme.Metric.cornerRadius`, height `Theme.Metric.fieldHeight`.

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/StyledTextFieldTests.swift
import XCTest
@testable import OST_Remote

final class StyledTextFieldTests: XCTestCase {
    func test_secureField_isSecureAndPasswordContentType() {
        let tf = StyledTextField(placeholder: "Password", secure: true)
        XCTAssertTrue(tf.isSecureTextEntry)
        XCTAssertEqual(tf.textContentType, .password)
        XCTAssertEqual(tf.placeholder, "Password")
    }

    func test_plainField_isNotSecure_usernameContentType() {
        let tf = StyledTextField(placeholder: "Username", secure: false)
        XCTAssertFalse(tf.isSecureTextEntry)
        XCTAssertEqual(tf.textContentType, .username)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:"OST TrackerTests/StyledTextFieldTests"`.
Expected: FAIL — `StyledTextField` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/StyledTextField.swift
import UIKit

/// Theme-styled text field used on the login screen. Carries the field fill,
/// rounded corners, and the appropriate autofill content type.
final class StyledTextField: UITextField {
    init(placeholder: String, secure: Bool) {
        super.init(frame: .zero)
        self.placeholder = placeholder
        borderStyle = .roundedRect
        backgroundColor = Theme.fieldFill
        font = Theme.Font.field
        textColor = Theme.label
        isSecureTextEntry = secure
        autocapitalizationType = .none
        autocorrectionType = .no
        textContentType = secure ? .password : .username
        layer.cornerRadius = Theme.Metric.cornerRadius
        heightAnchor.constraint(equalToConstant: Theme.Metric.fieldHeight).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run with `-only-testing:"OST TrackerTests/StyledTextFieldTests"`.
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/StyledTextField.swift" "OST TrackerTests/Swift/StyledTextFieldTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add StyledTextField component"
```

---

### Task 5: DisclosureSelectField (inline-expand picker)

**Files:**
- Create: `OST Tracker/Swift/DesignSystem/DisclosureSelectField.swift`
- Test: `OST TrackerTests/Swift/DisclosureSelectFieldTests.swift`

**Interfaces:**
- Produces: `final class DisclosureSelectField: UIView` with:
  - `init(label: String, placeholder: String)`
  - `var options: [String] { get set }` (setting rebuilds the option rows)
  - `private(set) var selectedOption: String?`
  - `private(set) var isExpanded: Bool`
  - `var onSelect: ((String) -> Void)?`
  - `func toggleExpanded()`
  - `func select(_ option: String)` — sets `selectedOption`, collapses, fires `onSelect`
  - `func reset()` — clears selection and collapses (used when the event changes)

- [ ] **Step 1: Write the failing test**

```swift
// OST TrackerTests/Swift/DisclosureSelectFieldTests.swift
import XCTest
@testable import OST_Remote

final class DisclosureSelectFieldTests: XCTestCase {
    func test_select_setsSelection_collapses_andFiresCallback() {
        let field = DisclosureSelectField(label: "Event", placeholder: "Choose an event")
        field.options = ["Bear 100 — 2026", "Wasatch 100"]
        var fired: String?
        field.onSelect = { fired = $0 }

        field.toggleExpanded()
        XCTAssertTrue(field.isExpanded)

        field.select("Wasatch 100")
        XCTAssertEqual(field.selectedOption, "Wasatch 100")
        XCTAssertFalse(field.isExpanded, "selecting collapses the list")
        XCTAssertEqual(fired, "Wasatch 100")
    }

    func test_toggleExpanded_flipsState() {
        let field = DisclosureSelectField(label: "Aid Station", placeholder: "Select…")
        XCTAssertFalse(field.isExpanded)
        field.toggleExpanded(); XCTAssertTrue(field.isExpanded)
        field.toggleExpanded(); XCTAssertFalse(field.isExpanded)
    }

    func test_reset_clearsSelectionAndCollapses() {
        let field = DisclosureSelectField(label: "Aid Station", placeholder: "Select…")
        field.options = ["A", "B"]
        field.select("A")
        field.reset()
        XCTAssertNil(field.selectedOption)
        XCTAssertFalse(field.isExpanded)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run with `-only-testing:"OST TrackerTests/DisclosureSelectFieldTests"`.
Expected: FAIL — `DisclosureSelectField` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// OST Tracker/Swift/DesignSystem/DisclosureSelectField.swift
import UIKit

/// Inline-expand selection field. A tappable header row shows a label, the current
/// value (or placeholder) and a chevron; tapping expands a short list of options in
/// place. Selecting an option collapses the list and fires `onSelect`. Built for
/// short lists (OST only surfaces live-mode events), so no search/scrolling.
final class DisclosureSelectField: UIView {

    var options: [String] = [] { didSet { rebuildOptionRows() } }
    private(set) var selectedOption: String?
    private(set) var isExpanded = false
    var onSelect: ((String) -> Void)?

    private let placeholder: String
    private let valueLabel = UILabel()
    private let chevron = UILabel()
    private let optionsStack = UIStackView()

    init(label: String, placeholder: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)
        buildHeader(label: label)
        valueLabel.text = placeholder
        valueLabel.textColor = Theme.secondaryLabel
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: Public behavior
    func toggleExpanded() {
        isExpanded.toggle()
        updateExpansion()
    }

    func select(_ option: String) {
        selectedOption = option
        valueLabel.text = option
        valueLabel.textColor = Theme.label
        isExpanded = false
        updateExpansion()
        onSelect?(option)
    }

    func reset() {
        selectedOption = nil
        valueLabel.text = placeholder
        valueLabel.textColor = Theme.secondaryLabel
        isExpanded = false
        updateExpansion()
    }

    // MARK: View construction
    private let header = UIControl()

    private func buildHeader(label: String) {
        translatesAutoresizingMaskIntoConstraints = false

        let caption = UILabel()
        caption.text = label.uppercased()
        caption.font = Theme.Font.caption
        caption.textColor = Theme.secondaryLabel

        header.backgroundColor = Theme.fieldFill
        header.layer.cornerRadius = Theme.Metric.cornerRadius
        header.layer.borderWidth = 1
        header.layer.borderColor = Theme.separator.cgColor
        header.addTarget(self, action: #selector(headerTapped), for: .touchUpInside)

        valueLabel.font = Theme.Font.field
        chevron.text = "▾"
        chevron.textColor = Theme.secondaryLabel

        let row = UIStackView(arrangedSubviews: [valueLabel, chevron])
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            header.heightAnchor.constraint(equalToConstant: Theme.Metric.fieldHeight),
        ])

        optionsStack.axis = .vertical
        optionsStack.isHidden = true

        let outer = UIStackView(arrangedSubviews: [caption, header, optionsStack])
        outer.axis = .vertical
        outer.spacing = 7
        outer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outer)
        NSLayoutConstraint.activate([
            outer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: trailingAnchor),
            outer.topAnchor.constraint(equalTo: topAnchor),
            outer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func rebuildOptionRows() {
        optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for option in options {
            let b = UIButton(type: .system)
            b.setTitle(option, for: .normal)
            b.setTitleColor(Theme.label, for: .normal)
            b.contentHorizontalAlignment = .left
            b.titleLabel?.font = Theme.Font.field
            b.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
            b.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
            optionsStack.addArrangedSubview(b)
        }
    }

    private func updateExpansion() {
        chevron.text = isExpanded ? "▴" : "▾"
        optionsStack.isHidden = !isExpanded
    }

    @objc private func headerTapped() { toggleExpanded() }

    @objc private func optionTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        select(title)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run with `-only-testing:"OST TrackerTests/DisclosureSelectFieldTests"`.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/Swift/DesignSystem/DisclosureSelectField.swift" "OST TrackerTests/Swift/DisclosureSelectFieldTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add DisclosureSelectField inline-expand picker"
```

---

### Task 6: Restyle LoginViewController onto the theme

**Files:**
- Modify: `OST Tracker/Swift/LoginViewController.swift`

**Interfaces:**
- Consumes: `Theme`, `PrimaryButton(title:role:)`, `StyledTextField(placeholder:secure:)`.

This is a refactor of an already-clean screen: swap hardcoded colors/fonts/metrics for `Theme`, replace the inline field/button factories with the new components, remove the unused `brandBlue`. Behavior (login flow, handoff to event selection) is unchanged, so the existing `LoginControllerTests` plus a build are the regression gate; visual confirmation is a manual step.

- [ ] **Step 1: Replace fields, button, and colors with components/theme**

In `LoginViewController.swift`:
- Delete the `brandBlue` property (line ~11) and the private `makeField` factory + the `textContentField` extension (they move into `StyledTextField`).
- Replace the field declarations:
  ```swift
  private let emailField = StyledTextField(placeholder: "Username", secure: false)
  private let passwordField = StyledTextField(placeholder: "Password", secure: true)
  ```
- Replace the `loginButton` closure with:
  ```swift
  private let loginButton = PrimaryButton(title: "Login", role: .success)
  ```
- In `viewDidLoad`, set `view.backgroundColor = Theme.background` (was `.white`) and `titleLabel.textColor = Theme.label`, `titleLabel.font = Theme.Font.title`.
- Leave the stack-view layout, safe-area constraints, spinner, and `didTapLogin`/`setLoading`/`showError` exactly as they are.

- [ ] **Step 2: Build and run existing login tests**

Run with `-only-testing:"OST TrackerTests/LoginControllerTests"`.
Expected: PASS (unchanged) and the app target compiles.

- [ ] **Step 3: Commit**

```bash
git add "OST Tracker/Swift/LoginViewController.swift"
git commit -m "refactor: restyle LoginViewController onto Theme + shared components"
```

- [ ] **Step 4: Manual verification (human)**

Launch the app; confirm the login screen renders with the themed fields/button and that login still reaches event selection. (Per project workflow, hand visual verification to the user.)

---

### Task 7: Rewrite OSTEventSelectionViewController (retire XIB)

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTEventSelectionViewController.swift`
- Delete: `OST Tracker/ViewControllers/OSTEventSelectionViewController.xib` (and remove its `project.pbxproj` reference + the Copy-Bundle-Resources entry)

**Interfaces:**
- Consumes: `Theme`, `PrimaryButton`, `DisclosureSelectField`.
- Preserves (unchanged): `@objc class func loadEventDataAndPresent(from:completion:)`, `@objc var changeStation/tempContext/events/eventStrings`, and the entire post-selection data path in `onNext` (`OSTBackend.getEventsDetails`, `CurrentCourse` creation, `EffortModel.mr_reconcile`, `AppDelegate.loadLeftMenu/showTracker`) and `onLogout` (connectivity check). Only view construction and the picker interaction change.

- [ ] **Step 1: Confirm no remaining XIB-outlet references before deleting**

Run:
```bash
grep -rn "imgTriangleAidStation\|eventTriangle\|@IBOutlet\|@IBAction" "OST Tracker/ViewControllers/OSTEventSelectionViewController.swift"
```
Expected after the rewrite: no matches. (Both external callers use only the public API — verified at plan time.)

- [ ] **Step 2: Replace the outlets + XIB lifecycle with programmatic views**

In `OSTEventSelectionViewController.swift`:
- Remove all `@IBOutlet` properties and the `viewDidLayoutSubviews` safe-area shift hack.
- Add programmatic views and a `loadView`/`viewDidLoad` that builds them:

```swift
// MARK: - Programmatic views
private let eventField = DisclosureSelectField(label: "Event", placeholder: "Choose an event")
private let stationField = DisclosureSelectField(label: "Aid Station", placeholder: "Select an aid station")
private let nextButton = PrimaryButton(title: "Start Tracking", role: .success)
private let logoutButton: UIButton = {
    let b = UIButton(type: .system)
    b.setTitle("Log Out", for: .normal)
    b.setTitleColor(Theme.destructive, for: .normal)
    return b
}()
private let cancelButton: UIButton = {
    let b = UIButton(type: .system)
    b.setTitle("Cancel", for: .normal)
    b.setTitleColor(Theme.tint, for: .normal)
    return b
}()
private let progressLabel: UILabel = {
    let l = UILabel(); l.textAlignment = .center; l.textColor = Theme.secondaryLabel
    l.font = Theme.Font.field; l.isHidden = true; return l
}()
private let progressBar: UIProgressView = {
    let p = UIProgressView(progressViewStyle: .default); p.isHidden = true; return p
}()
private let activityIndicator: UIActivityIndicatorView = {
    let s = UIActivityIndicatorView(style: .gray); s.hidesWhenStopped = true; return s
}()

override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Theme.background

    nextButton.alpha = 0
    stationField.isHidden = true
    nextButton.addTarget(self, action: #selector(onNext(_:)), for: .touchUpInside)
    logoutButton.addTarget(self, action: #selector(onLogout(_:)), for: .touchUpInside)
    cancelButton.addTarget(self, action: #selector(onCancel(_:)), for: .touchUpInside)

    eventField.onSelect = { [weak self] _ in self?.onEventSelected() }
    stationField.onSelect = { [weak self] _ in
        UIView.animate(withDuration: 0.3) { self?.nextButton.alpha = 1 }
    }

    let footer = changeStation ? cancelButton : logoutButton
    let stack = UIStackView(arrangedSubviews: [eventField, stationField, nextButton,
                                               progressLabel, progressBar, activityIndicator, footer])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    let guide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Theme.Metric.horizontalInset),
        stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Theme.Metric.horizontalInset),
        stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
    ])

    if changeStation {
        eventField.isUserInteractionEnabled = false
    }
}
```

- [ ] **Step 3: Port the mode logic onto the new fields**

Replace `viewDidAppear`, `onDoneSelectedEvent`/`onDoneSelectedStation`, `showSelectFields`/`showLoadingFields` with field-driven equivalents:

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if eventsLoaded { return }

    if changeStation {
        let course = CurrentCourse.getCurrentCourse()
        eventField.options = [course?.eventName ?? ""]
        eventField.select(course?.eventName ?? "")
        let stations = course?.dataEntryGroups as? [[String: Any]] ?? []
        stationField.options = stations.compactMap { $0["title"] as? String }
        stationField.isHidden = false
        unpairedDataEntryGroups = course?.dataEntryGroups as? [Any]
        return
    }

    eventField.options = (eventStrings as? [String]) ?? []
    eventsLoaded = true
    if (eventStrings?.count ?? 0) == 1, let only = (eventStrings as? [String])?.first {
        eventField.select(only)   // triggers onEventSelected via onSelect
    }
}

private func onEventSelected() {
    let eventModels = (events as? [EventModel]) ?? []
    guard let found = eventModels.first(where: { $0.name == eventField.selectedOption }) else { return }
    selectedEvent = found
    let groups = found.dataEntryGroups as? [[String: Any]] ?? []
    stationField.reset()
    stationField.options = groups.compactMap { $0["title"] as? String }
    UIView.animate(withDuration: 0.3) { self.stationField.isHidden = false }
}

private func showSelectFields() {
    [eventField, stationField, nextButton].forEach { $0.isHidden = false }
    progressLabel.isHidden = true; progressBar.isHidden = true; activityIndicator.stopAnimating()
}

private func showLoadingFields() {
    [eventField, stationField, nextButton].forEach { $0.isHidden = true }
    progressLabel.isHidden = false; progressBar.isHidden = false; activityIndicator.startAnimating()
}
```

- [ ] **Step 4: Update `onNext`/`onCancel`/`onLogout` to plain `@objc` (drop `@IBAction`) and the station read**

- Change `@IBAction func onNext/onCancel/onLogout` to `@objc func …` (signatures otherwise identical).
- In `onNext`, replace `txtStation.selectedItem` with `stationField.selectedOption` and `txtEvent.selectedItem` (in the progress label) with `eventField.selectedOption`. Keep the rest of `onNext` (the `getEventsDetails` block, `CurrentCourse` population, `mr_reconcile`, save, `loadLeftMenu`/`showTracker`) **exactly as-is**.

- [ ] **Step 5: Delete the XIB**

```bash
git rm "OST Tracker/ViewControllers/OSTEventSelectionViewController.xib"
```
Then remove the file's `PBXFileReference`, `PBXBuildFile`, and Copy-Bundle-Resources entries from `OST Tracker.xcodeproj/project.pbxproj` (search the file for `OSTEventSelectionViewController.xib`).

- [ ] **Step 6: Build the app target**

Run:
```bash
xcodebuild build -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```
Expected: BUILD SUCCEEDED, with no reference to the removed XIB or outlets.

- [ ] **Step 7: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTEventSelectionViewController.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "refactor: rewrite event selection as programmatic themed screen; retire XIB"
```

- [ ] **Step 8: Manual verification (human)**

Live login → event selection: confirm Event picker expands inline, choosing an event reveals Aid Station, choosing a station reveals Start Tracking, and the flow downloads course data and opens the tracker. Then Utilities → Change Station: confirm the event is locked and only the aid station is selectable, and Cancel dismisses.

---

### Task 8: Utilities — Appearance toggle

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTUtilitiesViewController.swift`
- Possibly modify: `OST Tracker/ViewControllers/OSTUtilitiesViewController.xib` (add a button row) — or add the control programmatically in `viewDidLoad` to avoid XIB edits.

**Interfaces:**
- Consumes: `AppearanceController.shared`, `AppearanceMode`.

Add an "Appearance" affordance that presents a *System · Light · Dark* action sheet and writes the choice to `AppearanceController.shared.mode` (the setter applies it immediately). On iOS 12 the affordance is hidden.

- [ ] **Step 1: Add the appearance action**

In `OSTUtilitiesViewController.swift` add:

```swift
@objc func onAppearance(_ sender: Any) {
    let sheet = UIAlertController(title: "Appearance", message: nil, preferredStyle: .actionSheet)
    let choose: (String, AppearanceMode) -> UIAlertAction = { title, mode in
        UIAlertAction(title: title, style: .default) { _ in AppearanceController.shared.mode = mode }
    }
    sheet.addAction(choose("System", .system))
    sheet.addAction(choose("Light", .light))
    sheet.addAction(choose("Dark", .dark))
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    if let pop = sheet.popoverPresentationController, let v = sender as? UIView {
        pop.sourceView = v; pop.sourceRect = v.bounds
    }
    present(sheet, animated: true)
}
```

- [ ] **Step 2: Add the row and gate it to iOS 13+**

In `viewDidLoad`, add a button wired to `onAppearance(_:)` (programmatically, to avoid XIB edits), and hide it on iOS 12:

```swift
let appearanceButton = UIButton(type: .system)
appearanceButton.setTitle("Appearance", for: .normal)
appearanceButton.addTarget(self, action: #selector(onAppearance(_:)), for: .touchUpInside)
appearanceButton.isHidden = !(ProcessInfo.processInfo.isOperatingSystemAtLeast(
    OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)))
```

Before writing this step, open `OSTUtilitiesViewController.swift` and its `.xib` and find how the existing rows (About, Change Station, Logout) are arranged — a stack view, a table, or pinned buttons. Add `appearanceButton` to that **same container** the same way (e.g. if they share a `UIStackView`, `stackView.insertArrangedSubview(appearanceButton, at: <index above Logout>)`; if they are XIB buttons with constraints, add it programmatically between the Change Station and Logout rows with matching leading/trailing constraints and height). Place it directly **above Logout**.

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild build -project "OST Tracker.xcodeproj" -scheme "OST Remote Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTUtilitiesViewController.swift"
git commit -m "feat: add Appearance toggle (System/Light/Dark) to Utilities"
```

- [ ] **Step 5: Manual verification (human)**

On an iOS 13+ device/sim: Utilities → Appearance → Dark flips the whole app dark; Light flips it back; System follows the device setting. On iOS 12 the row is absent.

---

## Notes for the executor

- Run the **full test suite** once at the end (`xcodebuild test … -scheme "OST Remote Dev"` with no `-only-testing`) to confirm nothing regressed.
- The four new design-system files live together under `OST Tracker/Swift/DesignSystem/`.
- Visual verification steps are handed to the user per project workflow; do the code/build/unit-test work autonomously in a batch first.
