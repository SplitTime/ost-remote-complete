//
//  OSTAboutViewController.swift
//  OST Tracker
//
//  Programmatic DesignSystem rewrite. A header (title + menu button with sync
//  badge), the OST wordmark, app name/version, grouped info cards for the
//  servers and contact, and a copyright line. The XIB is gone; all values
//  come from the bundle/Info.plist.
//

import UIKit

@objc(OSTAboutViewController)
class OSTAboutViewController: OSTBaseViewController {

    private let titleLabel = UILabel()
    private let badgeView = UILabel()

    private let logoView = UIImageView()
    private let appNameLabel = UILabel()
    private let versionLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()
        populateFromBundle()

        // Hand the base VC its badge label so updateSyncBadge keeps working.
        badgeLabel = badgeView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSyncBadge()
    }

    // MARK: - UI

    private func buildUI() {
        titleLabel.text = "About"
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = ScreenHeader.make(titleLabel: titleLabel,
                                       target: self,
                                       onLiveEntry: #selector(onLiveEntry),
                                       onMenu: #selector(onMenu))
        menuButton = header.menuButton

        // Count badge pinned to the menu button's top-trailing corner.
        badgeView.font = .systemFont(ofSize: 12, weight: .bold)
        badgeView.textColor = .white
        badgeView.backgroundColor = Theme.destructive
        badgeView.textAlignment = .center
        badgeView.layer.cornerRadius = 9
        badgeView.clipsToBounds = true
        badgeView.isHidden = true
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badgeView)

        // Wordmark — the "OST Logo" asset renders as a template, so tint it with
        // the label color to track light/dark.
        logoView.image = UIImage(named: "OST Logo")?.withRenderingMode(.alwaysTemplate)
        logoView.tintColor = Theme.label
        logoView.contentMode = .scaleAspectFit
        logoView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        appNameLabel.font = Theme.Font.title
        appNameLabel.textColor = Theme.label
        appNameLabel.textAlignment = .center

        versionLabel.font = Theme.Font.field
        versionLabel.textColor = Theme.secondaryLabel
        versionLabel.textAlignment = .center

        let brandStack = UIStackView(arrangedSubviews: [logoView, appNameLabel, versionLabel])
        brandStack.axis = .vertical
        brandStack.alignment = .center
        brandStack.spacing = 8
        brandStack.setCustomSpacing(16, after: logoView)

        let copyrightLabel = UILabel()
        copyrightLabel.text = "© 2026 OpenSplitTime Company"
        copyrightLabel.font = Theme.Font.caption
        copyrightLabel.textColor = Theme.secondaryLabel
        copyrightLabel.textAlignment = .center

        let contentStack = UIStackView(arrangedSubviews: [
            brandStack,
            card(title: "Server", rows: serverRows()),
            card(title: "Contact", rows: [infoRow(key: "Support", value: "support@opensplittime.org")]),
            copyrightLabel,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.setCustomSpacing(12, after: contentStack.arrangedSubviews[2])

        for v in [header.header, contentStack] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        let guide = view.safeAreaLayoutGuide
        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            header.header.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            header.header.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            header.header.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),

            contentStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            contentStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),
            contentStack.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: header.header.bottomAnchor, constant: 24),

            badgeView.topAnchor.constraint(equalTo: header.menuButton.topAnchor, constant: -4),
            badgeView.leadingAnchor.constraint(equalTo: header.menuButton.trailingAnchor, constant: -14),
            badgeView.heightAnchor.constraint(equalToConstant: 18),
            badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
        ])
    }

    private func populateFromBundle() {
        appNameLabel.text = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        versionLabel.text = "Version \(appVersion) (\(buildNumber))"
    }

    private func serverRows() -> [UIView] {
        var rows: [UIView] = []
        if let primary = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String {
            rows.append(infoRow(key: "URL", value: primary))
        }
        return rows
    }

    // MARK: - Card builders

    /// A grouped card: a caption-style section title above a rounded
    /// `secondaryBackground` panel whose rows are separated by hairlines.
    private func card(title: String, rows: [UIView]) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = Theme.Font.caption
        titleLabel.textColor = Theme.secondaryLabel

        let panel = UIStackView()
        panel.axis = .vertical
        panel.backgroundColor = Theme.secondaryBackground
        panel.layer.cornerRadius = Theme.Metric.cornerRadius
        panel.clipsToBounds = true
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)

        for (index, row) in rows.enumerated() {
            panel.addArrangedSubview(row)
            if index < rows.count - 1 {
                panel.addArrangedSubview(separator())
            }
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, panel])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func infoRow(key: String, value: String) -> UIView {
        let keyLabel = UILabel()
        keyLabel.text = key
        keyLabel.font = Theme.Font.field
        keyLabel.textColor = Theme.secondaryLabel
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        keyLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Theme.Font.field
        valueLabel.textColor = Theme.label
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6

        let row = UIStackView(arrangedSubviews: [keyLabel, valueLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.Metric.fieldHeight).isActive = true
        return row
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = Theme.separator
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    // MARK: - Actions

    @IBAction func onMenu(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc private func onLiveEntry() {
        AppDelegate.getInstance()?.showTracker()
    }
}
