//  CrossCheckActionSheet.swift
//  OST Tracker
//
//  Themed bottom sheet for one bib: shows bib + name, an Expected/Not-expected
//  segmented control (only for not-yet-recorded runners), and Review entries.
//  Replaces the legacy bulk-select popup with a single-bib action.

import UIKit

final class CrossCheckActionSheet: UIViewController {

    private let config: CrossCheckSheetConfig
    private let onSetExpected: (Bool) -> Void
    private let onReviewEntries: () -> Void

    private let segmented = UISegmentedControl(items: ["Expected", "Not expected"])

    private init(config: CrossCheckSheetConfig,
                 onSetExpected: @escaping (Bool) -> Void,
                 onReviewEntries: @escaping () -> Void) {
        self.config = config
        self.onSetExpected = onSetExpected
        self.onReviewEntries = onReviewEntries
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    static func present(from presenter: UIViewController,
                        config: CrossCheckSheetConfig,
                        onSetExpected: @escaping (Bool) -> Void,
                        onReviewEntries: @escaping () -> Void) {
        let sheet = CrossCheckActionSheet(config: config,
                                          onSetExpected: onSetExpected,
                                          onReviewEntries: onReviewEntries)
        presenter.present(sheet, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)

        let dimTap = UITapGestureRecognizer(target: self, action: #selector(onDismiss))
        view.addGestureRecognizer(dimTap)

        let card = UIView()
        card.backgroundColor = Theme.secondaryBackground
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false
        // Swallow taps so tapping inside the card doesn't dismiss.
        card.addGestureRecognizer(UITapGestureRecognizer(target: nil, action: nil))
        view.addSubview(card)

        let grabber = UIView()
        grabber.backgroundColor = Theme.separator
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        grabber.widthAnchor.constraint(equalToConstant: 36).isActive = true
        grabber.heightAnchor.constraint(equalToConstant: 5).isActive = true

        let bibLabel = UILabel()
        bibLabel.text = config.bib
        bibLabel.font = .systemFont(ofSize: 34, weight: .bold)
        bibLabel.textColor = Theme.label
        bibLabel.textAlignment = .center

        let nameLabel = UILabel()
        nameLabel.text = config.name
        nameLabel.font = Theme.Font.field
        nameLabel.textColor = Theme.secondaryLabel
        nameLabel.textAlignment = .center

        segmented.selectedSegmentIndex = config.isExpected ? 0 : 1
        segmented.isHidden = !config.showsExpectedToggle
        segmented.addTarget(self, action: #selector(onSegmentChanged), for: .valueChanged)

        let reviewButton = PrimaryButton(title: "Review entries", role: .primary)
        reviewButton.addTarget(self, action: #selector(onReviewTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [grabber, bibLabel, nameLabel, segmented, reviewButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(2, after: bibLabel)
        stack.setCustomSpacing(20, after: nameLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Center the grabber within the fill stack.
        grabber.setContentHuggingPriority(.required, for: .horizontal)

        card.addSubview(stack)

        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 18),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        // Keep the grabber centered.
        grabber.centerXAnchor.constraint(equalTo: card.centerXAnchor).isActive = true
    }

    @objc private func onSegmentChanged() {
        onSetExpected(segmented.selectedSegmentIndex == 0)
    }

    @objc private func onReviewTapped() {
        dismiss(animated: true) { [weak self] in self?.onReviewEntries() }
    }

    @objc private func onDismiss() {
        dismiss(animated: true)
    }
}
