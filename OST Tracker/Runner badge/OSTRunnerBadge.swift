import UIKit

/// Confirmation badge shown after a time is recorded: the bib number, the recorded
/// clock time (same `displayTime` the review/sync screen shows), the runner's
/// gender/age and any flag chips (Dropping / Pacer), plus a Confirm button and a
/// top-corner pencil cue (the whole badge is tappable to edit the entry). Rebuilt
/// in the design system — replaces the old Obj-C/XIB green clipboard badge. Keeps the
/// `@objc` API the runner tracker calls: `OSTRunnerBadge(frame:)`, `update(with:)`,
/// `adjustFontSizes()`. The host wires `confirmButton` and toggles its visibility.
@objc(OSTRunnerBadge)
final class OSTRunnerBadge: UIView {

    private let leadingPanel = UIView()
    private let checkLabel = UILabel()
    private let bibLabel = UILabel()
    private let timeLabel = UILabel()
    private let captionLabel = UILabel()
    /// Affordance hint: the whole badge is tappable to edit the just-recorded entry
    /// (the host wires the gesture). This pencil glyph in the top-trailing corner is
    /// the only visual cue for that, so don't drop it. Glyph-in-label matches the
    /// badge's `✓` and the menu's `☰` convention (no SF Symbols on the iOS 12 floor).
    private let pencilLabel = UILabel()
    private let droppingChip = OSTRunnerBadge.makeChip("DROPPING", color: Theme.destructive)
    private let pacerChip = OSTRunnerBadge.makeChip("PACER", color: Theme.tint)
    private let chipRow = UIStackView()

    /// Commit action for the just-recorded entry. The host wires the target and
    /// toggles `isHidden`; it lives inside the badge (center-bottom of the detail
    /// column) so it never overlaps the time the way a corner overlay did.
    let confirmButton = UIButton(type: .system)

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { super.init(coder: coder); build() }

    /// Populates the badge from the view model. `caption` (gender/age) and the flag
    /// chips are shown only when present.
    @objc func update(with viewModel: OSTRunnerBadgeViewModel) {
        bibLabel.text = viewModel.bibNumber
        timeLabel.text = viewModel.time
        captionLabel.text = viewModel.caption
        captionLabel.isHidden = (viewModel.caption ?? "").isEmpty
        droppingChip.isHidden = !viewModel.dropping
        pacerChip.isHidden = !viewModel.withPacer
        chipRow.isHidden = !(viewModel.dropping || viewModel.withPacer)
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
        checkLabel.font = .systemFont(ofSize: 28, weight: .bold)
        checkLabel.textColor = .white
        checkLabel.setContentHuggingPriority(.required, for: .horizontal)
        checkLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        bibLabel.font = .systemFont(ofSize: 38, weight: .bold)
        bibLabel.textColor = .white
        bibLabel.adjustsFontSizeToFitWidth = true
        bibLabel.minimumScaleFactor = 0.4

        // Bib row + flag chips beneath it, all in the roomy green panel (keeps the
        // detail column on the right uncramped).
        let bibRow = UIStackView(arrangedSubviews: [checkLabel, bibLabel])
        bibRow.spacing = 10
        bibRow.alignment = .center

        droppingChip.isHidden = true
        pacerChip.isHidden = true
        chipRow.axis = .horizontal
        chipRow.alignment = .center
        chipRow.spacing = 6
        chipRow.addArrangedSubview(droppingChip)
        chipRow.addArrangedSubview(pacerChip)
        chipRow.isHidden = true

        let leadingStack = UIStackView(arrangedSubviews: [bibRow, chipRow])
        leadingStack.axis = .vertical
        leadingStack.alignment = .center
        leadingStack.spacing = 8
        leadingStack.translatesAutoresizingMaskIntoConstraints = false
        leadingPanel.addSubview(leadingStack)

        // Detail column: time, caption, then the Confirm button — stacked and
        // centered so nothing overlaps.
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        timeLabel.textColor = Theme.label
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.4
        timeLabel.textAlignment = .center

        captionLabel.font = Theme.Font.caption
        captionLabel.textColor = Theme.secondaryLabel
        captionLabel.textAlignment = .center
        captionLabel.isHidden = true

        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.backgroundColor = Theme.tint
        confirmButton.layer.cornerRadius = 15
        confirmButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 20, bottom: 5, right: 20)
        confirmButton.isHidden = true

        let detailStack = UIStackView(arrangedSubviews: [timeLabel, captionLabel, confirmButton])
        detailStack.axis = .vertical
        detailStack.alignment = .center
        detailStack.spacing = 6
        detailStack.translatesAutoresizingMaskIntoConstraints = false

        // Tap-to-edit cue, pinned to the badge's top-trailing corner over the
        // light-green field. Decorative only — the badge-wide tap gesture does the work.
        pencilLabel.text = "\u{270E}"                       // ✎
        pencilLabel.font = .systemFont(ofSize: 16)
        pencilLabel.textColor = Theme.secondaryLabel
        pencilLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leadingPanel)
        addSubview(detailStack)
        addSubview(pencilLabel)

        NSLayoutConstraint.activate([
            pencilLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            pencilLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            leadingPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            leadingPanel.topAnchor.constraint(equalTo: topAnchor),
            leadingPanel.bottomAnchor.constraint(equalTo: bottomAnchor),
            leadingPanel.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.46),

            leadingStack.centerXAnchor.constraint(equalTo: leadingPanel.centerXAnchor),
            leadingStack.centerYAnchor.constraint(equalTo: leadingPanel.centerYAnchor),
            leadingStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingPanel.leadingAnchor, constant: 12),
            leadingStack.trailingAnchor.constraint(lessThanOrEqualTo: leadingPanel.trailingAnchor, constant: -12),

            detailStack.leadingAnchor.constraint(equalTo: leadingPanel.trailingAnchor, constant: 10),
            detailStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            detailStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 6),
            detailStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),
        ])
    }

    /// A small rounded flag chip (e.g. "DROPPING", "PACER").
    private static func makeChip(_ text: String, color: UIColor) -> UILabel {
        let l = PaddedLabel()
        l.text = text
        l.font = .systemFont(ofSize: 10, weight: .bold)
        l.textColor = .white
        l.backgroundColor = color
        l.layer.cornerRadius = 7
        l.clipsToBounds = true
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }
}

/// UILabel with horizontal padding, for pill-shaped chips.
private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
}
