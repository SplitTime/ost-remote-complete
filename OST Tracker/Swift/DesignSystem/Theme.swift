import UIKit

/// Semantic, theme-aware colors plus shared metrics and fonts. Screens and
/// components reference roles here — never raw colors. On iOS 13+ each role is a
/// dynamic UIColor that follows the trait collection; on iOS 12 it resolves to the
/// light value (the dynamic initializer does not exist there), so call sites are
/// identical on every OS version.
enum Theme {

    // MARK: Color roles
    static var background: UIColor { dynamic(light: Palette.lightBackground, dark: Palette.darkBackground) }
    static var secondaryBackground: UIColor { dynamic(light: Palette.lightSecondaryBackground, dark: Palette.darkSecondaryBackground) }
    static var fieldFill: UIColor { dynamic(light: Palette.lightFieldFill, dark: Palette.darkFieldFill) }
    static var separator: UIColor { dynamic(light: Palette.lightSeparator, dark: Palette.darkSeparator) }
    static var label: UIColor { dynamic(light: Palette.lightLabel, dark: Palette.darkLabel) }
    static var secondaryLabel: UIColor { dynamic(light: Palette.lightSecondaryLabel, dark: Palette.darkSecondaryLabel) }
    static var tint: UIColor { dynamic(light: Palette.lightTint, dark: Palette.darkTint) }
    static var success: UIColor { dynamic(light: Palette.lightSuccess, dark: Palette.darkSuccess) }
    static var destructive: UIColor { dynamic(light: Palette.lightDestructive, dark: Palette.darkDestructive) }

    // MARK: Metrics
    enum Metric {
        static let cornerRadius: CGFloat = 10
        static let fieldHeight: CGFloat = 48
        static let buttonHeight: CGFloat = 52
        static let horizontalInset: CGFloat = 28
    }

    // MARK: Fonts
    enum Font {
        static let title = UIFont.systemFont(ofSize: 30, weight: .bold)
        static let brand = UIFont.systemFont(ofSize: 22, weight: .bold)   // wordmark at list/header scale
        static let field = UIFont.systemFont(ofSize: 17)
        /// Bold variant of `field`, derived from its descriptor so the point size lives in one place.
        static let fieldBold = UIFont(descriptor: field.fontDescriptor.withSymbolicTraits(.traitBold) ?? field.fontDescriptor, size: 0)
        static let button = UIFont.systemFont(ofSize: 18, weight: .semibold)
        static let caption = UIFont.systemFont(ofSize: 12, weight: .semibold)
        static let clock = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let bib = UIFont.systemFont(ofSize: 64, weight: .bold)
        static let runnerName = UIFont.systemFont(ofSize: 24, weight: .bold)
        /// Returns `font` resized to `size`, preserving weight/traits. For iPad up-scaling.
        static func resized(_ font: UIFont, to size: CGFloat) -> UIFont {
            UIFont(descriptor: font.fontDescriptor, size: size)
        }
    }

    // MARK: Dynamic resolver
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
        }
        return light
    }
}

/// Raw palette values. Internal (not private) so tests can reference them.
enum Palette {
    static let lightBackground          = UIColor(white: 0.95, alpha: 1)           // systemGroupedBackground-ish
    static let darkBackground           = UIColor.black
    static let lightSecondaryBackground = UIColor.white
    static let darkSecondaryBackground  = UIColor(white: 0.11, alpha: 1)
    static let lightFieldFill           = UIColor.white
    static let darkFieldFill            = UIColor(white: 0.11, alpha: 1)
    static let lightSeparator           = UIColor(white: 0.90, alpha: 1)
    static let darkSeparator            = UIColor(white: 0.17, alpha: 1)
    static let lightLabel               = UIColor(white: 0.11, alpha: 1)
    static let darkLabel                = UIColor.white
    static let lightSecondaryLabel      = UIColor(white: 0.56, alpha: 1)
    static let darkSecondaryLabel       = UIColor(white: 0.56, alpha: 1)
    static let lightTint                = UIColor(red: 0/255,  green: 122/255, blue: 255/255, alpha: 1) // systemBlue
    static let darkTint                 = UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1)
    static let lightSuccess             = UIColor(red: 52/255, green: 199/255, blue: 89/255,  alpha: 1) // systemGreen
    static let darkSuccess              = UIColor(red: 48/255, green: 209/255, blue: 88/255,  alpha: 1)
    static let lightDestructive         = UIColor(red: 255/255, green: 59/255, blue: 48/255,  alpha: 1) // systemRed
    static let darkDestructive          = UIColor(red: 255/255, green: 69/255, blue: 58/255,  alpha: 1)
}
