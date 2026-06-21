import UIKit

/// Open single-select list: a section label plus one tappable row per option, each
/// with a trailing radio indicator. For short lists (e.g. live-mode events) shown
/// directly, with no dropdown. After a selection (when there is more than one
/// option) the list collapses to show only the chosen row with a chevron; tapping
/// that row re-expands the full list. Theme-styled.
final class SelectableOptionList: UIView {

    var options: [String] = [] { didSet { rebuildRows() } }
    private(set) var selectedOption: String?
    private(set) var isExpanded = true
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
        rowsStack.spacing = Theme.Metric.spacing

        let outer = UIStackView(arrangedSubviews: [caption, rowsStack])
        outer.axis = .vertical
        outer.spacing = Theme.Metric.spacing
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
        if options.count > 1 { isExpanded = false }  // nothing to collapse with one option
        refresh()
        onSelect?(option)
    }

    /// Re-show all options after a collapse (keeps the current selection).
    func expand() {
        isExpanded = true
        refresh()
    }

    func reset() {
        selectedOption = nil
        isExpanded = true
        refresh()
    }

    private func rebuildRows() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for option in options {
            let row = OptionRow(title: option)
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            rowsStack.addArrangedSubview(row)
        }
        refresh()
    }

    @objc private func rowTapped(_ sender: OptionRow) {
        if isExpanded {
            select(sender.title)
        } else {
            expand()  // tapping the collapsed selected row re-opens the list
        }
    }

    private func refresh() {
        for case let row as OptionRow in rowsStack.arrangedSubviews {
            let isSelected = row.title == selectedOption
            if isExpanded {
                row.isHidden = false
                row.accessory = isSelected ? .radioOn : .radioOff
            } else {
                row.isHidden = !isSelected   // collapsed: only the selected row shows
                row.accessory = .chevron
            }
        }
    }
}

/// One selectable row: title on the left, a trailing accessory (radio when shown
/// in the expanded list, or a chevron when it is the collapsed selection).
private final class OptionRow: UIControl {
    enum Accessory { case radioOff, radioOn, chevron }

    let title: String
    private let radio = UIView()
    private let chevron = UILabel()

    var accessory: Accessory = .radioOff { didSet { applyStyle() } }

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
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)  // stretch → accessory sits far right

        radio.translatesAutoresizingMaskIntoConstraints = false
        radio.layer.cornerRadius = 9
        radio.layer.borderWidth = 2
        radio.layer.borderColor = Theme.separator.cgColor
        radio.isUserInteractionEnabled = false

        chevron.text = "▾"
        chevron.textColor = Theme.secondaryLabel
        chevron.isUserInteractionEnabled = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, radio, chevron])
        row.alignment = .center
        row.spacing = Theme.Metric.spacing
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
        applyStyle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func applyStyle() {
        // Tinted border only when this row is the active selection in the expanded
        // list. The collapsed (chevron) state reads like a normal field.
        let tinted = (accessory == .radioOn)
        layer.borderColor = (tinted ? Theme.tint : Theme.separator).cgColor
        layer.borderWidth = tinted ? 2 : 1
        radio.isHidden = (accessory == .chevron)
        chevron.isHidden = (accessory != .chevron)
        radio.backgroundColor = (accessory == .radioOn) ? Theme.tint : .clear
        radio.layer.borderColor = (accessory == .radioOn ? Theme.tint : Theme.separator).cgColor
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if #available(iOS 13.0, *), traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            applyStyle()
        }
    }
}
