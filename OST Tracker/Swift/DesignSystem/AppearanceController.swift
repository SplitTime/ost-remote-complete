import UIKit

@objc enum AppearanceMode: Int {
    case system = 0   // raw 0 so UserDefaults' default (absent key → 0) means System
    case light  = 1
    case dark   = 2
}

/// Persists the user's appearance choice and applies it to the app window on
/// iOS 13+. No-op on iOS 12 (there is no theme to switch to).
@objc final class AppearanceController: NSObject {
    @objc static let shared = AppearanceController()

    private let key = "appearanceMode"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    @objc var mode: AppearanceMode {
        get { AppearanceMode(rawValue: defaults.integer(forKey: key)) ?? .system }
        set { defaults.set(newValue.rawValue, forKey: key); apply() }
    }

    @available(iOS 13.0, *)
    var interfaceStyle: UIUserInterfaceStyle {
        switch mode {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    @objc func apply() {
        guard #available(iOS 13.0, *) else { return }
        AppDelegate.getInstance()?.window?.overrideUserInterfaceStyle = interfaceStyle
    }
}
