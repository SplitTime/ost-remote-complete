import UIKit

/// One navigation row in the right menu: a title on the left, a trailing chevron,
/// an optional red count badge, and an optional spinner (for the syncing state).
/// Theme-styled. iOS 12-safe.
final class MenuRow: UIControl {

    let title: String

    private let titleLabel = UILabel()
    private let chevron = UILabel()
    private let badge = UILabel()
    private let spinner = UIActivityIndicatorView(style: .gray)
    private let detail = UILabel()

    init(title: String) {
        self.title = title
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = Theme.label
        // A long title truncates rather than shoving the chevron off the trailing edge.
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = Theme.destructive
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        spinner.hidesWhenStopped = true

        detail.font = .systemFont(ofSize: 15)
        detail.textColor = Theme.secondaryLabel
        detail.isHidden = true

        chevron.text = "›"
        chevron.font = .systemFont(ofSize: 18, weight: .semibold)
        chevron.textColor = Theme.secondaryLabel

        // Title pinned to the leading edge; the accessories (spinner/badge/detail)
        // and chevron pinned to the trailing edge. We deliberately avoid a single
        // .fill stack: its slack distribution is ambiguous on iOS 26 and can hand
        // the extra width to a hidden accessory instead of the title, stranding the
        // chevron mid-row. Anchoring the chevron to `trailing` keeps it flush-right
        // on every iOS version regardless of title length.
        let accessories = UIStackView(arrangedSubviews: [spinner, badge, detail, chevron])
        accessories.alignment = .center
        accessories.spacing = Theme.Metric.spacing
        accessories.isUserInteractionEnabled = false
        accessories.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(accessories)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Metric.rowInset),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            accessories.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: Theme.Metric.spacing),
            accessories.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Theme.Metric.rowInset),
            accessories.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: Theme.Metric.rowHeight),
            badge.heightAnchor.constraint(equalToConstant: 20),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    var badgeCount: Int = 0 {
        didSet {
            badge.isHidden = badgeCount <= 0
            badge.text = badgeCount > 0 ? "\(badgeCount)" : nil
        }
    }

    var showsSpinner: Bool = false {
        didSet { showsSpinner ? spinner.startAnimating() : spinner.stopAnimating() }
    }

    var detailText: String? {
        didSet {
            detail.text = detailText
            detail.isHidden = (detailText?.isEmpty ?? true)
        }
    }

    var showsChevron: Bool = true {
        didSet { chevron.isHidden = !showsChevron }
    }

    // Test seams.
    var isShowingBadge: Bool { !badge.isHidden }
    var badgeText: String? { badge.text }
    var isShowingDetail: Bool { !detail.isHidden }
    var detailLabelText: String? { detail.text }
    var isShowingChevron: Bool { !chevron.isHidden }
    var chevronMaxXInRow: CGFloat { chevron.convert(chevron.bounds, to: self).maxX }
}
