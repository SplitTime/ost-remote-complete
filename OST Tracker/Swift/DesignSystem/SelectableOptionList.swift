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
