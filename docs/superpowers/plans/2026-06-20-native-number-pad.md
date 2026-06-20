# Native Swift Number Pad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the vendored Objective-C `APNumberPad` with one shared, native-styled, all-Swift `NumberPadView`, and remove the now-unused `*` (unmatched-bib) feature.

**Architecture:** A single `UIView` subclass (`NumberPadView`) renders a 4-row keypad (digits 0–9 + backspace) using nested `UIStackView`s, styled like the iOS system keyboard. It edits an attached `UITextField` by mutating `.text` directly so existing KVO observers on the field still fire. It is used as an embedded subview in `OSTRunnerTrackerViewController` and as an `inputView` in `OSTEditEntryViewController`. The Obj-C library and the `*` code paths are then deleted.

**Tech Stack:** Swift, UIKit, XCTest. Build/test via the `OST Remote` Xcode scheme from `OST Tracker.xcodeproj` (no CocoaPods). The `xcodeproj` Ruby gem is used at build time only (not an app dependency) to register new files in `project.pbxproj`.

## Global Constraints

- Deployment target: **iOS 12.0** — no SF Symbols (use Unicode `⌫` U+232B), no APIs newer than iOS 12.
- **Zero app dependencies** — no new pods/frameworks. `xcodeproj` is a build-time dev gem only.
- App module name for `@testable import`: **`OST_Remote`**.
- New app Swift files belong to **both** app targets: `OST Remote` and `OST Remote Dev`.
- New test files belong to the **`OST TrackerTests`** target.
- Build/test scheme: **`OST Remote`**. Test simulator destination: **`platform=iOS Simulator,name=iPad mini (A17 Pro)`** (substitute any available simulator from `xcrun simctl list devices available` if that name is absent).
- All edits to the bib field must go through `textField.text` (direct assignment) — `OSTRunnerTrackerViewController` drives its live roster lookup via KVO on the field's `"text"` key path.

---

### Task 0: Add the file-registration helper script

**Files:**
- Create: `scripts/add_file_to_xcodeproj.rb`

**Interfaces:**
- Produces: a CLI script `ruby scripts/add_file_to_xcodeproj.rb <relative_file_path> <target_name> [<target_name>...]` that registers an on-disk file into the named targets of `OST Tracker.xcodeproj` (idempotent).

- [ ] **Step 1: Install the build-time gem**

Run: `gem install xcodeproj`
Expected: ends with `Successfully installed xcodeproj-…` (if it requires elevated permissions, run `sudo gem install xcodeproj`). Verify: `ruby -e "require 'xcodeproj'; puts 'ok'"` prints `ok`.

- [ ] **Step 2: Write the helper script**

```ruby
#!/usr/bin/env ruby
# Usage: ruby scripts/add_file_to_xcodeproj.rb <relative_file_path> <target_name> [<target_name>...]
# Idempotently registers an existing file into the given targets of the project.
require 'xcodeproj'

file_path = ARGV[0]
target_names = ARGV[1..-1]
abort "usage: add_file_to_xcodeproj.rb <file> <target> [<target>...]" if file_path.nil? || target_names.empty?

project = Xcodeproj::Project.open('OST Tracker.xcodeproj')

dir = File.dirname(file_path)
group = project.main_group.find_subpath(dir, true)
group.set_source_tree('SOURCE_ROOT') if group.source_tree.nil?

abs = File.expand_path(file_path)
file_ref = group.files.find { |f| f.real_path.to_s == abs } || group.new_reference(abs)

target_names.each do |name|
  target = project.targets.find { |t| t.name == name }
  abort "target not found: #{name}" unless target
  already = target.source_build_phase.files_references.include?(file_ref)
  target.add_file_references([file_ref]) unless already
end

project.save
puts "Registered #{file_path} -> #{target_names.join(', ')}"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/add_file_to_xcodeproj.rb
git commit -m "build: add xcodeproj file-registration helper script"
```

---

### Task 1: `NumberPadView` component (TDD)

**Files:**
- Create: `OST Tracker/Swift/NumberPadView.swift`
- Test: `OST TrackerTests/Swift/NumberPadViewTests.swift`

**Interfaces:**
- Produces:
  - `final class NumberPadView: UIView`
  - `var textField: UITextField?` (weak)
  - `func attach(to textField: UITextField)`
  - `func insertDigit(_ digit: String)` (appends to `textField.text`)
  - `func deleteBackward()` (drops last char of `textField.text`; no-op if empty/nil)

- [ ] **Step 1: Write the failing test**

Create `OST TrackerTests/Swift/NumberPadViewTests.swift`:

```swift
import XCTest
@testable import OST_Remote

final class NumberPadViewTests: XCTestCase {

    func test_insertDigit_appendsToTextField() {
        let field = UITextField()
        let pad = NumberPadView()
        pad.attach(to: field)

        pad.insertDigit("2")
        pad.insertDigit("2")

        XCTAssertEqual(field.text, "22")
    }

    func test_deleteBackward_removesLastCharacter() {
        let field = UITextField()
        field.text = "123"
        let pad = NumberPadView()
        pad.attach(to: field)

        pad.deleteBackward()

        XCTAssertEqual(field.text, "12")
    }

    func test_deleteBackward_onEmptyField_isNoOp() {
        let field = UITextField()
        let pad = NumberPadView()
        pad.attach(to: field)

        pad.deleteBackward()

        XCTAssertEqual(field.text ?? "", "")
    }

    func test_insertDigit_withNoAttachedField_doesNotCrash() {
        let pad = NumberPadView()
        pad.insertDigit("5")
        // No attached field: nothing to assert beyond "did not crash".
    }
}
```

- [ ] **Step 2: Register the test file with the test target**

Run: `ruby scripts/add_file_to_xcodeproj.rb "OST TrackerTests/Swift/NumberPadViewTests.swift" "OST TrackerTests"`
Expected: `Registered OST TrackerTests/Swift/NumberPadViewTests.swift -> OST TrackerTests`

- [ ] **Step 3: Run the test to verify it fails**

Run:
```bash
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' \
  -only-testing:"OST TrackerTests/NumberPadViewTests" test 2>&1 | tail -20
```
Expected: build/compile FAILS with "cannot find 'NumberPadView' in scope" (the type does not exist yet).

- [ ] **Step 4: Write the implementation**

Create `OST Tracker/Swift/NumberPadView.swift`:

```swift
import UIKit

/// All-Swift replacement for the retired Obj-C `APNumberPad`.
///
/// Renders a native-styled keypad: digits 0–9 plus a backspace key, with a
/// blank bottom-left cell exactly like the system `.numberPad`. Edits its
/// attached text field by assigning `.text` directly so existing KVO observers
/// on the field continue to fire (the runner tracker watches the bib field via
/// KVO on "text").
final class NumberPadView: UIView {

    /// Field this pad edits. Weak to avoid a retain cycle with the host.
    weak var textField: UITextField?

    private let backspaceGlyph = "\u{232B}" // ⌫

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        buildGrid()
    }

    /// Connect the pad to a text field (mirrors APNumberPad's `setTextField:`).
    func attach(to textField: UITextField) {
        self.textField = textField
    }

    // MARK: - Editing

    func insertDigit(_ digit: String) {
        guard let field = textField else { return }
        field.text = (field.text ?? "") + digit
    }

    func deleteBackward() {
        guard let field = textField, let text = field.text, !text.isEmpty else { return }
        field.text = String(text.dropLast())
    }

    // MARK: - Layout

    private func buildGrid() {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["",  "0", backspaceGlyph],
        ]

        let rowStacks: [UIStackView] = rows.map { row in
            let stack = UIStackView(arrangedSubviews: row.map(makeKey))
            stack.axis = .horizontal
            stack.distribution = .fillEqually
            stack.spacing = 6
            return stack
        }

        let grid = UIStackView(arrangedSubviews: rowStacks)
        grid.axis = .vertical
        grid.distribution = .fillEqually
        grid.spacing = 6
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            grid.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    private func makeKey(_ title: String) -> UIView {
        // Empty cell: a non-interactive spacer, matching native `.numberPad`.
        guard !title.isEmpty else { return UIView() }

        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28)
        button.backgroundColor = .white
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.setBackgroundImage(solidImage(UIColor(white: 0.82, alpha: 1)), for: .highlighted)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func keyTapped(_ sender: UIButton) {
        let title = sender.title(for: .normal) ?? ""
        if title == backspaceGlyph {
            deleteBackward()
        } else {
            insertDigit(title)
        }
    }

    private func solidImage(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}
```

- [ ] **Step 5: Register the implementation file with both app targets**

Run: `ruby scripts/add_file_to_xcodeproj.rb "OST Tracker/Swift/NumberPadView.swift" "OST Remote" "OST Remote Dev"`
Expected: `Registered OST Tracker/Swift/NumberPadView.swift -> OST Remote, OST Remote Dev`

- [ ] **Step 6: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' \
  -only-testing:"OST TrackerTests/NumberPadViewTests" test 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **` with all four `NumberPadViewTests` passing.

- [ ] **Step 7: Commit**

```bash
git add "OST Tracker/Swift/NumberPadView.swift" "OST TrackerTests/Swift/NumberPadViewTests.swift" "OST Tracker.xcodeproj/project.pbxproj"
git commit -m "feat: add native Swift NumberPadView (replaces Obj-C APNumberPad)"
```

---

### Task 2: Integrate `NumberPadView` into `OSTEditEntryViewController`

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTEditEntryViewController.swift` (class decl line 23; setup lines 86–89; delegate method lines 230–235)

**Interfaces:**
- Consumes: `NumberPadView`, `attach(to:)` from Task 1.

- [ ] **Step 1: Remove the `APNumberPadDelegate` conformance**

Change line 23 from:

```swift
class OSTEditEntryViewController: UIViewController, APNumberPadDelegate {
```

to:

```swift
class OSTEditEntryViewController: UIViewController {
```

- [ ] **Step 2: Replace the pad setup**

Replace lines 86–89:

```swift
        let numberPad = APNumberPad(delegate: self)
        numberPad.leftFunctionButton.setTitle("*", for: .normal)
        numberPad.leftFunctionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        txtBibNumber.inputView = numberPad
```

with:

```swift
        let numberPad = NumberPadView()
        numberPad.attach(to: txtBibNumber)
        txtBibNumber.inputView = numberPad
```

- [ ] **Step 3: Delete the function-button delegate method**

Remove lines 230–235 entirely:

```swift
    // MARK: - APNumberPadDelegate

    func numberPad(_ numberPad: APNumberPad, functionButtonAction functionButton: UIButton,
                   textInput: UIResponder & UITextInput) {
        textInput.insertText("*")
    }
```

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTEditEntryViewController.swift"
git commit -m "refactor: use NumberPadView in edit-entry; drop * key"
```

---

### Task 3: Integrate `NumberPadView` into `OSTRunnerTrackerViewController` + remove `*` lookup branch

**Files:**
- Modify: `OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift` (class decl line 20; setup lines 117–124; lookup lines 443–446; delegate method lines 507–516)

**Interfaces:**
- Consumes: `NumberPadView`, `attach(to:)` from Task 1.

- [ ] **Step 1: Remove the `APNumberPadDelegate` conformance**

Change line 20 from:

```swift
class OSTRunnerTrackerViewController: OSTBaseViewController, APNumberPadDelegate, UITextFieldDelegate {
```

to:

```swift
class OSTRunnerTrackerViewController: OSTBaseViewController, UITextFieldDelegate {
```

- [ ] **Step 2: Replace the embedded pad setup**

Replace lines 117–124:

```swift
        let numberPad = APNumberPad(delegate: self)
        numberPad.leftFunctionButton.setTitle("*", for: .normal)
        numberPad.leftFunctionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        numberPad.frame = numberPadContainerView.bounds
        numberPad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        numberPad.backgroundColor = .clear
        numberPadContainerView.addSubview(numberPad)
        numberPad.setTextField(txtBibNumber)
```

with:

```swift
        let numberPad = NumberPadView()
        numberPad.frame = numberPadContainerView.bounds
        numberPad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        numberPadContainerView.addSubview(numberPad)
        numberPad.attach(to: txtBibNumber)
```

- [ ] **Step 3: Remove the dead `*` lookup branch**

Replace lines 443–446:

```swift
        var effort: EffortModel?
        if !bib.contains("*") {
            effort = EffortModel.mr_findFirst(with: NSPredicate(format: "bibNumber == %@", NSDecimalNumber(string: bib))) as? EffortModel
        }
```

with:

```swift
        let effort = EffortModel.mr_findFirst(with: NSPredicate(format: "bibNumber == %@", NSDecimalNumber(string: bib))) as? EffortModel
```

- [ ] **Step 4: Delete the function-button delegate method**

Remove lines 507–516 entirely:

```swift
    // MARK: - APNumberPadDelegate

    func numberPad(_ numberPad: APNumberPad, functionButtonAction functionButton: UIButton,
                   textInput: UIResponder & UITextInput) {
        if let textField = textInput as? UITextField {
            textField.text = "\(textField.text ?? "")*"
        } else {
            textInput.insertText("*")
        }
    }
```

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add "OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift"
git commit -m "refactor: use NumberPadView in runner tracker; remove dead * lookup branch"
```

---

### Task 4: Delete the Obj-C `APNumberPad` library

**Files:**
- Delete: `OST Tracker/APNumberPad/` (entire directory)
- Modify: `OST Tracker/OST Tracker-Bridging-Header.h` (line 33, the `#import "APNumberPad.h"`)
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (remove file/group references)

**Interfaces:**
- Consumes: nothing. This task only removes code that Tasks 2–3 stopped referencing.

- [ ] **Step 1: Confirm no remaining Swift/header references**

Run: `grep -rn "APNumberPad" "OST Tracker" --include="*.swift" | grep -v "OST Tracker/APNumberPad/"`
Expected: only the bridging-header line (`OST Tracker-Bridging-Header.h:33`) — no `.swift` matches. If any `.swift` match remains, fix it before proceeding.

- [ ] **Step 2: Remove the bridging-header import**

In `OST Tracker/OST Tracker-Bridging-Header.h`, delete line 33:

```objc
#import "APNumberPad.h"
```

- [ ] **Step 3: Remove the project references**

Run:
```bash
ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("OST Tracker.xcodeproj")
project.files.select { |f| f.real_path.to_s.include?("/APNumberPad/") }.each(&:remove_from_project)
group = project.main_group.find_subpath("OST Tracker/APNumberPad", false)
group.remove_from_project if group
project.save
puts "Removed APNumberPad references from project"
'
```
Expected: `Removed APNumberPad references from project`

- [ ] **Step 4: Delete the directory from disk**

Run: `rm -rf "OST Tracker/APNumberPad"`
Verify: `ls "OST Tracker/APNumberPad" 2>&1` prints "No such file or directory".

- [ ] **Step 5: Verify nothing references it anywhere**

Run: `grep -rin "apnumberpad" "OST Tracker" "OST Tracker.xcodeproj/project.pbxproj"`
Expected: no output (exit status 1).

- [ ] **Step 6: Full build + test to verify the app is intact**

Run:
```bash
xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' test 2>&1 | tail -25
```
Expected: `** TEST SUCCEEDED **` (full suite, including `NumberPadViewTests`).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: delete vendored Obj-C APNumberPad library"
```

---

## Manual Verification (user-driven, per project convention)

After the automated steps pass, the user verifies visually in the simulator:

1. **Runner tracker** — embedded keypad renders (native white keys, ⌫ glyph, blank bottom-left, no `*`). Type a known bib → roster match displays (confirms the KVO lookup path still fires). Type an unknown bib → "Bib Not Found". Backspace edits correctly. Record an entry and confirm `bibNumber` is correct.
2. **Edit entry** — tapping the bib field shows the `NumberPadView` as the keyboard; digits and backspace work; no `*` key.

## Self-Review Notes

- **Spec coverage:** shared `NumberPadView` (Task 1) ✓; modern/iOS-12-safe styling + ⌫ glyph (Task 1) ✓; embedded use in RunnerTracker (Task 3) ✓; `inputView` use in EditEntry (Task 2) ✓; `.text`/KVO preservation (Task 1 impl + Task 3 manual check) ✓; `*` key removed + dead lookup branch removed + delegate methods removed (Tasks 2–3) ✓; delete `APNumberPad/` dir + bridging import + pbxproj refs (Task 4) ✓; unit + manual testing (Task 1 + Manual Verification) ✓.
- **Type consistency:** `NumberPadView`, `attach(to:)`, `insertDigit(_:)`, `deleteBackward()` used identically across all tasks.
- **No placeholders:** every code/command step contains concrete content.
