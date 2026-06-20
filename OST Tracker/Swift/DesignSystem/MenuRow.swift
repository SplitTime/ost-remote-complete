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

    init(title: String) {
        self.title = title
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = Theme.label
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = Theme.destructive
        badge.textAlignment = .center
        badge.layer.cornerRadius = 10
        badge.clipsToBounds = true
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        spinner.hidesWhenStopped = true

        chevron.text = "›"
        chevron.font = .systemFont(ofSize: 18, weight: .semibold)
        chevron.textColor = Theme.secondaryLabel

        let row = UIStackView(arrangedSubviews: [titleLabel, spinner, badge, chevron])
        row.alignment = .center
        row.spacing = 8
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 52),
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

    // Test seams.
    var isShowingBadge: Bool { !badge.isHidden }
    var badgeText: String? { badge.text }
}
