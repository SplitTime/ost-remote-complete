import UIKit

/// Slide-up bottom drawer for selecting from a list. iOS 12-safe (no
/// UISheetPresentationController): presented over full screen with a dimmed,
/// tap-to-dismiss scrim and a constraint-animated bottom panel. Theme-styled.
final class BottomSheetPicker: UIViewController {

    private let sheetTitle: String
    private let options: [String]
    private let preselected: String?
    private let onSelect: (String) -> Void

    private let scrim = UIView()
    private let panel = UIView()
    private var panelBottom: NSLayoutConstraint!

    init(title: String, options: [String], selected: String?, onSelect: @escaping (String) -> Void) {
        self.sheetTitle = title
        self.options = options
        self.preselected = selected
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    static func present(from presenter: UIViewController, title: String, options: [String],
                        selected: String?, onSelect: @escaping (String) -> Void) {
        let vc = BottomSheetPicker(title: title, options: options, selected: selected, onSelect: onSelect)
        presenter.present(vc, animated: false) { vc.animateIn() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrim.backgroundColor = UIColor.black.withAlphaComponent(0)
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        view.addSubview(scrim)

        panel.backgroundColor = Theme.background
        panel.layer.cornerRadius = 16
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let grab = UIView()
        grab.backgroundColor = Theme.separator
        grab.layer.cornerRadius = 2.5
        grab.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = sheetTitle
        header.font = Theme.Font.button
        header.textColor = Theme.label
        header.textAlignment = .center

        let rows = UIStackView()
        rows.axis = .vertical
        for option in options {
            let row = SheetRow(title: option, checked: option == preselected)
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            rows.addArrangedSubview(row)
        }
        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "BottomSheetPicker.scroll"
        scroll.translatesAutoresizingMaskIntoConstraints = false
        rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(rows)

        let content = UIStackView(arrangedSubviews: [grab, header, scroll])
        content.axis = .vertical
        content.spacing = 12
        content.setCustomSpacing(8, after: grab)
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(content)

        panelBottom = panel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 600) // start off-screen
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelBottom,
            panel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),

            grab.widthAnchor.constraint(equalToConstant: 36),
            grab.heightAnchor.constraint(equalToConstant: 5),
            grab.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            content.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            content.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            rows.topAnchor.constraint(equalTo: scroll.topAnchor),
            rows.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            rows.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        // A UIScrollView has no intrinsic content height, so inside the vertical
        // content stack it would collapse to zero (hiding every row). Size it to
        // its content, but at a priority that yields to the panel's top cap so a
        // long list scrolls within the available height instead of overflowing.
        let scrollHeight = scroll.heightAnchor.constraint(equalTo: rows.heightAnchor)
        scrollHeight.priority = .defaultHigh
        scrollHeight.isActive = true
    }

    func animateIn() {
        view.layoutIfNeeded()
        panelBottom.constant = 0
        UIView.animate(withDuration: 0.28) {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            self.view.layoutIfNeeded()
        }
    }

    private func animateOut(then completion: (() -> Void)?) {
        panelBottom.constant = 600
        UIView.animate(withDuration: 0.22, animations: {
            self.scrim.backgroundColor = UIColor.black.withAlphaComponent(0)
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    /// Testable seam: select an option (fires callback, then dismisses).
    func choose(_ option: String) {
        onSelect(option)
        animateOut(then: nil)
    }

    @objc private func rowTapped(_ sender: SheetRow) { choose(sender.title) }
    @objc private func dismissTapped() { animateOut(then: nil) }
}

private final class SheetRow: UIControl {
    let title: String
    init(title: String, checked: Bool) {
        self.title = title
        super.init(frame: .zero)
        backgroundColor = Theme.fieldFill

        let label = UILabel()
        label.text = title
        label.font = Theme.Font.field
        label.textColor = checked ? Theme.tint : Theme.label

        let check = UILabel()
        check.text = checked ? "✓" : ""
        check.textColor = Theme.tint
        check.font = Theme.Font.field

        let sep = UIView()
        sep.backgroundColor = Theme.separator
        sep.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [label, check])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        addSubview(row)
        addSubview(sep)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 52),
            sep.heightAnchor.constraint(equalToConstant: 1),
            sep.leadingAnchor.constraint(equalTo: leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}
