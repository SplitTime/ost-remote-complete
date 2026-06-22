import UIKit

/// Filled, theme-styled action button. `.primary` uses the brand tint;
/// `.success` uses the green confirm color (e.g. "Start Tracking").
final class PrimaryButton: UIButton {
    enum Role { case primary, success }

    init(title: String, role: Role = .primary) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = Theme.Font.button
        setTitleColor(.white, for: .normal)
        backgroundColor = (role == .success) ? Theme.success : Theme.tint
        layer.cornerRadius = Theme.Metric.cornerRadius
        heightAnchor.constraint(equalToConstant: Theme.Metric.buttonHeight).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

extension UIButton {
    /// Style this button as the standard right-drawer hamburger used in every screen
    /// header — one glyph, size, and tint so the menu affordance is identical
    /// everywhere (some screens previously showed "Menu ☰", others a bare "☰").
    func configureAsMenuButton(target: Any?, action: Selector) {
        setTitle("\u{2630}", for: .normal)        // ☰
        setTitleColor(Theme.tint, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 26)
        accessibilityLabel = "Menu"
        addTarget(target, action: action, for: .touchUpInside)
    }

    /// Style this button as the leading "‹ Live Entry" breadcrumb shown in every
    /// non-live screen's header utility row — one tap back to bib entry. Mirrors
    /// `configureAsMenuButton` so the affordance is identical on every screen.
    func configureAsBreadcrumb(target: Any?, action: Selector) {
        setTitle("\u{2039} Live Entry", for: .normal)   // ‹ Live Entry
        setTitleColor(Theme.tint, for: .normal)
        titleLabel?.font = Theme.Font.button
        contentHorizontalAlignment = .leading
        accessibilityLabel = "Back to Live Entry"
        addTarget(target, action: action, for: .touchUpInside)
    }
}
