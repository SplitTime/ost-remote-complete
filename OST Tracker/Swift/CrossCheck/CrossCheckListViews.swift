//  CrossCheckListViews.swift
//  OST Tracker
//
//  Design-system list cells for the Cross Check board. Colors map through Theme.

import UIKit

extension CrossCheckStatus {
    // Static so each status maps to a single UIColor instance; this lets
    // == comparisons (identity-backed for UIDynamicProviderColor) succeed in tests.
    private static let colors: [CrossCheckStatus: UIColor] = [
        .expected:    Theme.warning,
        .recorded:    Theme.success,
        .droppedHere: Theme.destructive,
        .notExpected: Theme.secondaryLabel,
    ]

    // The dict is exhaustive over all cases; the fallback only guards a future
    // case from becoming a runtime crash (and keeps a single instance per status).
    var dotColor: UIColor { CrossCheckStatus.colors[self] ?? Theme.secondaryLabel }
}

/// A "still out" row: large bib + full name + chevron.
final class CrossCheckExpectedCell: UITableViewCell {
    static let reuseID = "CrossCheckExpectedCell"

    private let bibLabel = UILabel()
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.secondaryBackground
        contentView.backgroundColor = Theme.secondaryBackground
        accessoryType = .disclosureIndicator
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func buildUI() {
        bibLabel.font = .systemFont(ofSize: 22, weight: .bold)
        bibLabel.textColor = Theme.label
        bibLabel.setContentHuggingPriority(.required, for: .horizontal)
        bibLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        nameLabel.font = Theme.Font.field
        nameLabel.textColor = Theme.label

        let row = UIStackView(arrangedSubviews: [bibLabel, nameLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with row: CrossCheckRow) {
        bibLabel.text = row.bib
        nameLabel.text = row.name
    }

    var bibText: String? { bibLabel.text }
    var nameText: String? { nameLabel.text }
}

/// A compact summary row: status dot + title + count + chevron.
final class CrossCheckSummaryCell: UITableViewCell {
    static let reuseID = "CrossCheckSummaryCell"

    private let dot = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.secondaryBackground
        contentView.backgroundColor = Theme.secondaryBackground
        accessoryType = .disclosureIndicator
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func buildUI() {
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        titleLabel.font = Theme.Font.field
        titleLabel.textColor = Theme.label

        countLabel.font = Theme.Font.field
        countLabel.textColor = Theme.secondaryLabel

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [dot, titleLabel, spacer, countLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }

    func configure(status: CrossCheckStatus, title: String, count: Int) {
        dot.backgroundColor = status.dotColor
        titleLabel.text = title
        countLabel.text = "\(count)"
    }

    var titleText: String? { titleLabel.text }
    var countText: String? { countLabel.text }
    var dotColor: UIColor? { dot.backgroundColor }
}
