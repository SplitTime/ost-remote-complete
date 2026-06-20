import UIKit
import AudioToolbox

/// Native Swift number pad view that replaces the retired Obj-C keypad library.
///
/// Renders a native-styled keypad: digits 0–9 plus a backspace key, with a
/// blank bottom-left cell exactly like the system `.numberPad`. Edits its
/// attached text field by assigning `.text` directly so existing KVO observers
/// on the field continue to fire (the runner tracker watches the bib field via
/// KVO on "text").
final class NumberPadView: UIView {

    /// How a key tap produces sound.
    enum TapSound {
        /// System keyboard click; honors the user's iOS "Keyboard Clicks"
        /// setting. Only audible when the pad is a text field's `inputView`.
        case systemKeyboardClick
        /// Always plays the standard keyboard click, regardless of system
        /// settings. Use for an embedded pad that is not an `inputView`.
        case alwaysClick
    }

    /// Sound played on each key tap. Defaults to the system-configurable click,
    /// which suits the `inputView` usage; embedded hosts set `.alwaysClick`.
    var tapSound: TapSound = .systemKeyboardClick

    /// Field this pad edits. Weak to avoid a retain cycle with the host.
    weak var textField: UITextField?

    private let backspaceGlyph = "\u{232B}" // ⌫

    /// Default size used when created without a frame, so the pad still has
    /// height when assigned as a text field `inputView` (a zero-height input
    /// view renders nothing). Embedded hosts override the frame.
    private static let defaultSize = CGSize(width: 320, height: 260)

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        if bounds.isEmpty {
            frame = CGRect(origin: .zero, size: Self.defaultSize)
        }
        autoresizingMask = .flexibleWidth
        backgroundColor = .clear
        buildGrid()
    }

    /// Connect the pad to a text field so it can edit its contents.
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
        button.setTitleColor(Theme.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28)
        button.backgroundColor = Theme.secondaryBackground
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 1
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.setBackgroundImage(solidImage(Theme.separator), for: .highlighted)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func keyTapped(_ sender: UIButton) {
        playClick()
        let title = sender.title(for: .normal) ?? ""
        if title == backspaceGlyph {
            deleteBackward()
        } else {
            insertDigit(title)
        }
    }

    private func playClick() {
        switch tapSound {
        case .systemKeyboardClick:
            // Only audible when this view is the current inputView; honors the
            // user's iOS "Keyboard Clicks" setting via UIInputViewAudioFeedback.
            UIDevice.current.playInputClick()
        case .alwaysClick:
            // 1104 is the standard keyboard click; plays for embedded pads where
            // playInputClick() is a no-op (not part of the input-view hierarchy).
            AudioServicesPlaySystemSound(1104)
        }
    }

    private func solidImage(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}

// Lets the system keyboard click play for the `.systemKeyboardClick` mode when
// the pad is used as a text field `inputView`.
extension NumberPadView: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
