# Runner-Entry Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `OSTRunnerTrackerViewController` (the core bib-entry screen) in the new design language as one adaptive Auto Layout hierarchy, replacing the XIB and all frame-math.

**Architecture:** Programmatic UIKit. A root vertical `UIStackView` pinned to the safe area hosts header → display zone → toggle row → entry buttons → number pad. All styling flows through `Theme`. Business logic (recording, bib lookup, KVO bridge, sounds) is preserved verbatim; only view construction and layout are rewritten. Adaptivity (iPad / landscape) is expressed with constraints and font scaling, not per-device frame branches.

**Tech Stack:** Swift, UIKit, Auto Layout, the existing `Theme` / `PrimaryButton` design system, `NumberPadView`, `OSTRunnerBadge`.

## Global Constraints

- **iOS 12 floor.** Only iOS 12-safe APIs: Auto Layout, `UIStackView` (iOS 9+), `safeAreaLayoutGuide` (iOS 11+). Dark mode is iOS 13+ and degrades via `Theme.dynamic` → light on iOS 12. No SF Symbols as sole affordances.
- **Zero dependencies.** Build/test from `OST Tracker.xcodeproj`, scheme `OST Remote`. No CocoaPods/workspace.
- **Never hardcode colors/fonts** — always reference `Theme` roles (project rule). DRY.
- **Preserve `@objc` contracts:** `@objc(OSTRunnerTrackerViewController)`; `txtBibNumber` `@objc` `UITextField` property (used by `OSTRightMenuViewController.m`); `@objc func cleanData()`; post `OSTRunnerTrackerViewControllerDidRegisterBibNotification` on record.
- **KVO lifecycle stays balanced** — observe `txtBibNumber.text`; keep the add/remove guards in `onEntryButton` and `deinit` exactly as today.
- **Build command (the per-task test cycle):**
  `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/ci build`
- **Unit test command:**
  `xcodebuild -project "OST Tracker.xcodeproj" -scheme "OST Remote" -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/ci test`
- Delete `build/` before committing (never commit build artifacts).

---

### Task 1: Add display font roles to Theme

**Files:**
- Modify: `OST Tracker/Swift/DesignSystem/Theme.swift` (the `Font` enum)

**Interfaces:**
- Produces: `Theme.Font.clock` (large bold, ~34pt), `Theme.Font.bib` (extra-large bold, ~64pt), `Theme.Font.runnerName` (bold, ~24pt). Used by Task 3. Provide an iPad-scaled variant via a helper `Theme.Font.scaled(_ base: UIFont, pad: CGFloat) -> UIFont` OR expose both phone/pad sizes — implementer picks the cleaner option but it MUST be defined in `Theme`, not the VC.

- [ ] **Step 1: Add the roles.** In `Theme.Font`, add:

```swift
static let clock      = UIFont.systemFont(ofSize: 34, weight: .bold)
static let bib        = UIFont.systemFont(ofSize: 64, weight: .bold)
static let runnerName = UIFont.systemFont(ofSize: 24, weight: .bold)
/// Returns `font` resized to `size`, preserving weight/traits. For iPad up-scaling.
static func resized(_ font: UIFont, to size: CGFloat) -> UIFont {
    UIFont(descriptor: font.fontDescriptor, size: size)
}
```

- [ ] **Step 2: Build.** Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit.**

```bash
rm -rf build && git add "OST Tracker/Swift/DesignSystem/Theme.swift"
git commit -m "feat(theme): add clock/bib/runnerName display font roles"
```

---

### Task 2: Theme the NumberPadView keys

**Files:**
- Modify: `OST Tracker/Swift/NumberPadView.swift:105-122` (`makeKey`)
- Test: `OST TrackerTests/Swift/NumberPadViewTests.swift` (existing — must stay green)

**Interfaces:**
- Consumes: `Theme.secondaryBackground`, `Theme.label`, `Theme.separator`.
- Produces: no API change — `NumberPadView` keeps `attach(to:)`, `tapSound`, `insertDigit`, `deleteBackward`.

- [ ] **Step 1: Replace hardcoded key colors.** In `makeKey`, swap:
  - `button.setTitleColor(.black, for: .normal)` → `Theme.label`
  - `button.backgroundColor = .white` → `Theme.secondaryBackground`
  - highlight image `UIColor(white: 0.82, alpha: 1)` → `Theme.separator`
  Keep the shadow (it reads fine in both modes) and corner radius.

- [ ] **Step 2: Run unit tests.** Run the unit test command. Expected: `NumberPadViewTests` PASS (the tests exercise digit insert/delete, not color — they must remain green).

- [ ] **Step 3: Commit.**

```bash
rm -rf build && git add "OST Tracker/Swift/NumberPadView.swift"
git commit -m "feat(numberpad): theme keys (Theme colors, dark-mode aware)"
```

---

### Task 3: Rebuild OSTRunnerTrackerViewController programmatically

**Files:**
- Rewrite: `OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift`

**Interfaces:**
- Consumes: `Theme` (colors, `Font.clock/.bib/.runnerName/.button/.caption`, `Metric`), `Theme.resized`, `NumberPadView`, `OSTRunnerBadge(frame:)` + `OSTRunnerBadgeViewModel`, `PrimaryButton` (or its styling), `EffortModel`, `EntryModel`, `CurrentCourse`, `OSTSound`, `AppDelegate.getInstance()?.rightMenuVC`.
- Produces (preserved external surface): `@objc(OSTRunnerTrackerViewController)`; `@objc var txtBibNumber: UITextField!`; `@objc func cleanData()`; posts `OSTRunnerTrackerViewControllerDidRegisterBibNotification`.

**Build the views in code** (no XIB). Replace every `@IBOutlet` with a programmatic property; replace `viewWillAppear`/`viewWillLayoutSubviews`/`viewWillTransition` frame-math with constraints. Preserve method bodies of `onEntryButton`, `updateBibInfo`, `onButtonPacer`, `onBtnStopped`, `onRunnerInfo`, `onTick`, `runnerBadgeViewModel`, `saveContext`, `textField(_:shouldChangeCharactersIn:…)`, and the KVO `observeValue` — changing only the references that pointed at old outlets/styling.

- [ ] **Step 1: Skeleton + contracts.** Create the class with programmatic properties: `txtBibNumber` (`@objc`), `numberPad`, `lblTitle`, `lblTime`/`lblTimeOfDay`, `btnMenu`, entry buttons `btnLeft`/`btnRight` with overlaid count-badge labels `lblInTimeBadge`/`lblOutTimeBadge`, toggles `btnStopped`/`btnPacer`, `lblPersonAdded` (name), `lblRunnerInfo`/`lblSecondaryInfo`, `runnerBadge` (`OSTRunnerBadge`). Implement `loadView()`/`viewDidLoad()` building the root vertical `UIStackView` (header, display zone, toggle row, entry-button row, number-pad container) pinned to `view.safeAreaLayoutGuide`. Style every element via `Theme`. Wire actions: `btnMenu → onRight`, toggles → `onButtonPacer`/`onBtnStopped`, entry buttons → `onEntryButton`, badge/info tap → `onRunnerInfo`. Embed `NumberPadView` (`.alwaysClick`) and `numberPad.attach(to: txtBibNumber)`. Add the `text` KVO observer; keep `deinit` removal.

- [ ] **Step 2: Port logic verbatim.** Bring over `onTick`, `updateBibInfo` (incl. "Bib Not Found" → `Theme.destructive` instead of the hardcoded red, name/secondary via `Theme.label`/`secondaryLabel`), `onEntryButton` (incl. the KVO remove/add guards and `DidRegisterBib` post), `onButtonPacer`, `onBtnStopped`, `onRunnerInfo` (present `OSTEditEntryViewController`; its deleted/updated blocks now recolor via `Theme.destructive`/`Theme.label`), `runnerBadgeViewModel`, `saveContext`, the 4-digit `textField` limiter, and `cleanData`.

- [ ] **Step 3: Entry-button permutations.** Reproduce the data-driven setup from the old `viewWillAppear` (read `splitAttributes["entries"]`, filter `subSplitKind` in/out): 1-in, 1-out, 1-in+1-out, 2-in, 2-out — setting button titles, visibility, and `leftBitKey`/`rightBitKey` identically. Drive layout by hiding a button in the horizontal stack (stack handles spacing) instead of width math. Apply the `monitorPacers` check to show/hide the pacer toggle.

- [ ] **Step 4: Adaptivity.** In `viewWillLayoutSubviews` (or trait/transition hooks), scale `Theme.Font.clock/.bib/.runnerName` and entry-button height up on `.pad` via `Theme.resized`; for landscape, switch the display-zone↔number-pad arrangement (e.g. a stack `.axis` flip or activating an alternate constraint set). No absolute frames; no `applySafeAreaShift` (safe-area guide replaces it).

- [ ] **Step 5: Build.** Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Unit tests.** Run the unit test command. Expected: existing suites PASS.

- [ ] **Step 7: Commit.**

```bash
rm -rf build && git add "OST Tracker/ViewControllers/OSTRunnerTrackerViewController.swift"
git commit -m "feat(runner-entry): rebuild bib-entry screen in new design language"
```

---

### Task 4: Remove the XIB

**Files:**
- Delete: `OST Tracker/ViewControllers/OSTRunnerTrackerViewController.xib`
- Modify: `OST Tracker.xcodeproj/project.pbxproj` (via helper)

**Interfaces:**
- Consumes: the repo helper `remove_file_from_xcodeproj.rb` (mirror of the add helper; see recent commit `16eae2c`).

- [ ] **Step 1: Remove from the project.** Run the helper to drop the XIB's PBX references, e.g.:

```bash
ruby remove_file_from_xcodeproj.rb "OST Tracker/ViewControllers/OSTRunnerTrackerViewController.xib"
```

(If the helper's invocation differs, read its header for usage. Then `git rm` the file if still present.)

- [ ] **Step 2: Confirm no nib auto-load.** Grep that nothing references the nib by name: `grep -rn "OSTRunnerTrackerViewController" --include=*.swift --include=*.m --include=*.h .` — only the class symbol should remain, no `.xib`/nib-name string.

- [ ] **Step 3: Build (proves the screen runs without the XIB).** Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit.**

```bash
rm -rf build && git add -A
git commit -m "chore(runner-entry): remove obsolete XIB and PBX references"
```

---

## Notes for the implementer

- Read the pre-rewrite `OSTRunnerTrackerViewController.swift` (git show the parent commit) for the exact logic bodies — port them, don't reinvent.
- Mirror the construction/Auto-Layout style of `OSTLiveReadsViewController.swift`.
- The entry-button permutation logic is the highest-risk area — keep the `leftBitKey`/`rightBitKey` semantics byte-for-byte.
- Hand visual verification to the user (batch-autonomous, then human verify).
