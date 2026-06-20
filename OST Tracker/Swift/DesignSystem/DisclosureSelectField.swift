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
