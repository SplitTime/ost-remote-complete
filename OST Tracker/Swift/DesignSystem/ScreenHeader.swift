import UIKit

/// Builds the standard two-line screen header shared by every non-live screen:
/// a utility row (`‹ Live Entry` breadcrumb · spacer · caller's action buttons ·
/// hamburger) over the screen's title on its own line. Keeps the breadcrumb,
/// title font, and hamburger identical everywhere (DRY), and returns the
/// hamburger so the base VC can keep anchoring its sync badge to it.
enum ScreenHeader {
    static func make(titleLabel: UILabel,
                     trailingActions: [UIView] = [],
                     target: Any?,
                     onLiveEntry: Selector,
                     onMenu: Selector) -> (header: UIStackView, menuButton: UIButton) {
        titleLabel.font = Theme.Font.title
        titleLabel.textColor = Theme.label

        let breadcrumb = UIButton(type: .system)
        breadcrumb.configureAsBreadcrumb(target: target, action: onLiveEntry)

        let menuButton = UIButton(type: .system)
        menuButton.configureAsMenuButton(target: target, action: onMenu)

        let utilityRow = UIStackView(arrangedSubviews: [breadcrumb, UIView()] + trailingActions + [menuButton])
        utilityRow.axis = .horizontal
        utilityRow.alignment = .center
        utilityRow.spacing = 12

        let header = UIStackView(arrangedSubviews: [utilityRow, titleLabel])
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = 4

        return (header, menuButton)
    }
}
