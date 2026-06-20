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
