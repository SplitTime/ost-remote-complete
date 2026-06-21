import UIKit

/// Confirmation badge shown after a time is recorded: the bib number, the recorded
/// clock time (same `displayTime` the review/sync screen shows), and a "tap to edit"
/// affordance, on a success-tinted card. Rebuilt in the design system — replaces the
/// old Obj-C/XIB green clipboard badge. Keeps the same `@objc` API the runner tracker
/// calls: `OSTRunnerBadge(frame:)`, `update(with:)`, `adjustFontSizes()`.
@objc(OSTRunnerBadge)
final class OSTRunnerBadge: UIView {

    private let leadingPanel = UIView()
    private let checkLabel = UILabel()
    private let bibLabel = UILabel()
    private let timeLabel = UILabel()
    private let captionLabel = UILabel()
    private let calloutLabel = UILabel()

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { super.init(coder: coder); build() }

    /// Populates the badge from the view model. `caption` (gender/age) is optional.
    @objc func update(with viewModel: OSTRunnerBadgeViewModel) {
        bibLabel.text = viewModel.bibNumber
        timeLabel.text = viewModel.time
        captionLabel.text = viewModel.caption
        captionLabel.isHidden = (viewModel.caption ?? "").isEmpty
    }

    /// Retained for API compatibility with the runner tracker. Auto Layout + the
    /// labels' `adjustsFontSizeToFitWidth` handle sizing, so this is a no-op.
    @objc func adjustFontSizes() {}

    private func build() {
        layer.cornerRadius = Theme.Metric.cornerRadius
        clipsToBounds = true
        backgroundColor = Theme.success.withAlphaComponent(0.14)

        // Leading panel: solid success green with a checkmark + bib number in white.
        leadingPanel.backgroundColor = Theme.success
        leadingPanel.translatesAutoresizingMaskIntoConstraints = false

        checkLabel.text = "✓"
        checkLabel.font = .systemFont(ofSize: 30, weight: .bold)
        checkLabel.textColor = .white
        checkLabel.setContentHuggingPriority(.required, for: .horizontal)
        checkLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        bibLabel.font = .systemFont(ofSize: 40, weight: .bold)
        bibLabel.textColor = .white
        bibLabel.adjustsFontSizeToFitWidth = true
        bibLabel.minimumScaleFactor = 0.4

        let leadingStack = UIStackView(arrangedSubviews: [checkLabel, bibLabel])
        leadingStack.spacing = 10
        leadingStack.alignment = .center
        leadingStack.translatesAutoresizingMaskIntoConstraints = false
        leadingPanel.addSubview(leadingStack)

        // Trailing: recorded time (monospaced digits) over a "tap to edit" hint, with
        // the optional caption (gender/age) between them.
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        timeLabel.textColor = Theme.label
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.4
        timeLabel.textAlignment = .center

        captionLabel.font = Theme.Font.caption
        captionLabel.textColor = Theme.secondaryLabel
        captionLabel.textAlignment = .center
        captionLabel.isHidden = true

        calloutLabel.text = "TAP TO EDIT"
        calloutLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        calloutLabel.textColor = Theme.secondaryLabel
        calloutLabel.textAlignment = .center

        let trailingStack = UIStackView(arrangedSubviews: [timeLabel, captionLabel, calloutLabel])
        trailingStack.axis = .vertical
        trailingStack.alignment = .center
        trailingStack.spacing = 2
        trailingStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leadingPanel)
        addSubview(trailingStack)

        NSLayoutConstraint.activate([
            leadingPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            leadingPanel.topAnchor.constraint(equalTo: topAnchor),
            leadingPanel.bottomAnchor.constraint(equalTo: bottomAnchor),
            leadingPanel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.46),

            leadingStack.centerXAnchor.constraint(equalTo: leadingPanel.centerXAnchor),
            leadingStack.centerYAnchor.constraint(equalTo: leadingPanel.centerYAnchor),
            leadingStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingPanel.leadingAnchor, constant: 12),
            leadingStack.trailingAnchor.constraint(lessThanOrEqualTo: leadingPanel.trailingAnchor, constant: -12),

            trailingStack.leadingAnchor.constraint(equalTo: leadingPanel.trailingAnchor, constant: 10),
            trailingStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            trailingStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
