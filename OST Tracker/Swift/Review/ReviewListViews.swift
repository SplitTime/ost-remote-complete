//  ReviewListViews.swift
//  OST Tracker
//
//  Design-system list views for the Review/Sync screen. Both consume the pure
//  presentation values from ReviewPresentation and map roles → Theme colors.

import UIKit

final class ReviewEntryCell: UITableViewCell {
    static let reuseID = "ReviewEntryCell"

    private let timeLabel = UILabel()
    private let nameLabel = UILabel()
    private let bibLabel = UILabel()
    private let inOutLabel = UILabel()
    private let pacerView = UIImageView()
    private let stoppedView = UIImageView()
    private let checkLabel = UILabel()

    private(set) var appliedStyle: ReviewEntryStyle?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.secondaryBackground
        contentView.backgroundColor = Theme.secondaryBackground
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func buildUI() {
        timeLabel.font = Theme.Font.field
        bibLabel.font = Theme.Font.field
        inOutLabel.font = Theme.Font.field
        nameLabel.font = Theme.Font.field
        // The name hugs its own text and sits flush after the time; only a very
        // long name (low compression resistance) truncates rather than shoving the
        // right-hand group off the cell.
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for v in [pacerView, stoppedView] {
            v.contentMode = .scaleAspectFit
            v.widthAnchor.constraint(equalToConstant: 22).isActive = true
            v.heightAnchor.constraint(equalToConstant: 22).isActive = true
        }
        let icons = UIStackView(arrangedSubviews: [pacerView, stoppedView])
        icons.spacing = 6

        // The "synced" confirmation lives here, not in the text color: a single green
        // check at the trailing edge. Hidden on unsynced rows (the stack collapses the
        // slot), so the right-hand group stays trailing-flush in both states.
        checkLabel.text = "\u{2713}" // ✓
        checkLabel.font = Theme.Font.fieldBold
        checkLabel.textColor = Theme.success
        checkLabel.setContentHuggingPriority(.required, for: .horizontal)

        // A single empty spacer absorbs all the row's slack, so every row lays out
        // identically regardless of which icons (if any) are showing: time + name
        // flush on the left, icon → bib → In/Out group flush on the right. Relying
        // on a label to stretch is ambiguous — a UILabel and the icon UIStackView
        // both default to content-hugging 250 and the stack splits slack between
        // them unpredictably. The spacer is the only low-hugging view, so it wins.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [timeLabel, nameLabel, spacer, icons, bibLabel, inOutLabel, checkLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with display: ReviewEntryDisplay) {
        let style = ReviewEntryStyle(display)
        appliedStyle = style

        timeLabel.text = display.time
        nameLabel.text = display.name
        bibLabel.text = display.bib ?? ""
        inOutLabel.text = display.inOut

        timeLabel.textColor = color(for: style.timeRole)
        nameLabel.textColor = color(for: style.nameRole)
        bibLabel.textColor = color(for: style.bibRole)
        inOutLabel.textColor = color(for: style.inOutRole)
        nameLabel.font = style.nameBold ? Theme.Font.fieldBold : Theme.Font.field

        pacerView.image = UIImage(named: display.isSynced ? "Pacer Symbol Green" : "Pacer Symbol Blue")
        stoppedView.image = UIImage(named: display.isSynced ? "Green Hand" : "Red Hand")
        pacerView.isHidden = !display.showsPacer
        stoppedView.isHidden = !display.showsStopped

        // A synced row reads as confirmed via a faint green wash + the trailing check;
        // an unsynced row stays on the plain cell background with no check.
        checkLabel.isHidden = !style.isSynced
        let fill = style.isSynced ? Theme.successFill : Theme.secondaryBackground
        backgroundColor = fill
        contentView.backgroundColor = fill
    }

    private func color(for role: ReviewLabelRole) -> UIColor {
        switch role {
        case .normal:      return Theme.label
        case .secondary:   return Theme.secondaryLabel
        case .success:     return Theme.success
        case .destructive: return Theme.destructive
        }
    }

    // Test seams
    var nameText: String? { nameLabel.text }
    var timeText: String? { timeLabel.text }
    var bibText: String? { bibLabel.text }
    var inOutText: String? { inOutLabel.text }
    var isPacerHidden: Bool { pacerView.isHidden }
    var isStoppedHidden: Bool { stoppedView.isHidden }
    var isCheckHidden: Bool { checkLabel.isHidden }
    var isSyncedRow: Bool { appliedStyle?.isSynced ?? false }
}

final class ReviewSectionHeaderView: UITableViewHeaderFooterView {
    static let reuseID = "ReviewSectionHeaderView"

    private let titleLabel = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        titleLabel.font = Theme.Font.caption
        titleLabel.textColor = Theme.secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(title: String) { titleLabel.text = title }

    // Test seam
    var titleText: String? { titleLabel.text }
}
