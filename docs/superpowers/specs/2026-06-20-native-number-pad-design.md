# Native Swift Number Pad — Design

**Date:** 2026-06-20
**Status:** Approved (pending spec review)
**Branch:** swiftui-rewrite

## Problem

Bib-number entry uses `APNumberPad`, a vendored Objective-C library (~620 lines across
`OST Tracker/APNumberPad/`). It is the last hand-maintained Obj-C UI component in the
app. Goals for replacing it:

1. **Drop the Obj-C** — move to an all-Swift, single-source-of-truth keypad.
2. **Modern / iOS-standard look & feel** — match the rewrite's modernization direction.
3. No UX regression (there is no current UX complaint driving this).

## Decision

Build **one shared Swift component, `NumberPadView` (a `UIView`)**, that replaces
`APNumberPad` in both places it is used, and delete the Obj-C library entirely.

Rejected alternatives:

- **Literal native `UIKeyboardType.numberPad`.** Native number pads exist *only* as the
  transient slide-up keyboard; they cannot be pinned into a container view. That breaks
  `OSTRunnerTrackerViewController`, where the pad is a permanent on-screen control on the
  live-timing screen. Using native only in `OSTEditEntryViewController` would leave two
  divergent keypads — against the consistency goal and DRY.
- **Restyle `APNumberPad` in place.** Keeps the Obj-C; fails goal 1.

## The `*` key is removed (feature deletion, deliberate)

The old pad had a `leftFunctionButton` relabeled `*` that appended an asterisk to the bib.
Tracing it end-to-end:

- A starred bib **skips** the local roster lookup
  (`OSTRunnerTrackerViewController.swift:444`, `if !bib.contains("*")`), so it always falls
  into the "Bib Not Found" display branch.
- The raw bib string (including `*`) is persisted as `entry.bibNumber`
  (`OSTRunnerTrackerViewController.swift:294`) and submitted to OpenSplitTime via
  `LiveTimeEntry`.

Net effect: the only thing `*` does is **suppress the local roster-match preview** for an
on-roster bib. The backend matches the bib regardless, so that suppression has no
downstream value. The feature is unused by the timer and volunteers and provides nothing.

**It is removed entirely** — the key *and* its now-dead handling code. Removing it also
makes the new pad more native (blank bottom-left, like iOS `.numberPad`).

## Component: `NumberPadView`

A self-contained `UIView` subclass. New Swift file under `OST Tracker/Swift/`
(e.g. `Swift/NumberPadView.swift`).

### Public interface

```swift
final class NumberPadView: UIView {
    /// The text field this pad edits. Held weakly; mutations go through `.text`
    /// so existing KVO observers on the field continue to fire.
    weak var textField: UITextField?

    init(frame: CGRect = .zero)
    func attach(to textField: UITextField)   // replaces APNumberPad's setTextField:
}
```

No delegate protocol is needed — with `*` gone there are no function buttons, so there is
nothing for a host to handle. (This deletes `APNumberPadDelegate` and both
`numberPad(_:functionButtonAction:...)` implementations.)

### Layout

A 4-row grid built with nested `UIStackView`s (vertical stack of four horizontal rows),
laid out with Auto Layout, `autoresizingMask`-friendly so it fills its container:

```
 1   2   3
 4   5   6
 7   8   9
     0   ⌫
```

Bottom-left cell is empty (a transparent, non-interactive placeholder), matching the
native pad.

### Styling (modern, iOS-12-safe)

- **Keys:** white rounded-rect (`cornerRadius` ~5), dark text, system font ~size 25–28,
  subtle key shadow — the standard iOS keyboard key look.
- **Touch highlight:** light-gray highlighted state on each key.
- **Backdrop:** `backgroundColor` is caller-configurable and defaults to `.clear`
  (RunnerTracker embeds it over a custom background and currently sets `.clear`;
  EditEntry uses it as an `inputView`).
- **Backspace glyph:** Unicode **⌫** (U+232B). SF Symbols (`delete.left`) require iOS 13;
  deployment target is iOS 12.0, so the Unicode glyph is the native-looking, supported
  choice. If the floor ever moves to iOS 13, switch to the `delete.left` symbol.

### Behavior

- **Digit tap:** append the digit to `textField?.text`.
- **Backspace tap:** remove the last character of `textField?.text` (no-op if empty).
- **Long-press backspace (optional, parity):** clear the field. Low priority; include only
  if cheap. Native `.numberPad` has no clear, so omitting it is also acceptable.
- All edits **mutate `textField.text` directly**, exactly as `APNumberPad` did. This is
  required: `OSTRunnerTrackerViewController` observes the field via **KVO on `"text"`**
  (`viewDidLoad`, `addObserver(...forKeyPath: "text"...)`), and that observer is what
  drives the live roster lookup. Direct `.text` assignment is what made KVO fire before;
  preserve it.

## Integration

### `OSTRunnerTrackerViewController` (embedded keypad)

Replace:

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

with a `NumberPadView` created, framed to `numberPadContainerView.bounds` with the same
`autoresizingMask`, added as a subview, and `attach(to: txtBibNumber)`.

Then:

- Delete the `APNumberPadDelegate` conformance and the `numberPad(_:functionButtonAction:...)`
  method.
- Delete the `if !bib.contains("*")` guard at line 444 — the lookup always runs.

### `OSTEditEntryViewController` (slide-up `inputView`)

Replace the `APNumberPad` setup with a `NumberPadView` assigned as
`txtBibNumber.inputView`. Delete the `APNumberPadDelegate` conformance and the
function-button method.

### Removals

- Delete the entire `OST Tracker/APNumberPad/` directory and its Xcode group/file
  references in `project.pbxproj`.
- Remove `APNumberPad` imports from `OST Tracker/OST Tracker-Bridging-Header.h`.
- Confirm no remaining references (`grep -ri apnumberpad`).

## Error handling / edge cases

- **Nil/empty field:** backspace on empty text is a no-op.
- **Detached field:** if `textField` is nil (deallocated), taps are no-ops.
- **KVO parity:** verify the RunnerTracker live lookup still fires on every key (it relies
  on `.text` KVO). This is the single highest-risk behavior — call it out in verification.

## Testing

- **Unit:** a small test exercising `NumberPadView` digit/backspace logic against a real
  `UITextField` (append builds the string; backspace trims; empty backspace is safe).
- **Manual (user-verified, per project convention):**
  1. RunnerTracker — type a known bib → roster match displays (KVO path works); type an
     unknown bib → "Bib Not Found"; backspace edits correctly; record an entry and confirm
     `bibNumber` is correct.
  2. EditEntry — pad appears as the keyboard, edits the bib, no `*` key present.
  3. Build is clean with `APNumberPad/` fully removed.

## Out of scope

- Any change to other text inputs (date/time pickers, login fields).
- Dark mode (iOS 12 has none).
- Re-adding any `*` / unmatched-bib workflow.
