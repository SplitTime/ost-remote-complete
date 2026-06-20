//
//  UIViewController+OSTSpinner.swift
//  OST Tracker
//
//  Shared native blocking spinner — a dimmed full-screen overlay with a centered
//  activity indicator. Replaces the DejalBezelActivityView usages across the
//  migrated Swift screens. Tag-based so it needs no stored state.
//

import UIKit

extension UIViewController {
    private var ostSpinnerTag: Int { 99_060_1 }

    /// Shows a dimmed full-screen overlay with a centered spinner (idempotent).
    func ostShowBlockingSpinner() {
        guard view.viewWithTag(ostSpinnerTag) == nil else { return }
        let overlay = UIView(frame: view.bounds)
        overlay.tag = ostSpinnerTag
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.35)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let spinner = UIActivityIndicatorView(style: .whiteLarge)
        spinner.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY)
        spinner.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin,
                                    .flexibleLeftMargin, .flexibleRightMargin]
        spinner.startAnimating()
        overlay.addSubview(spinner)
        view.addSubview(overlay)
    }

    func ostHideBlockingSpinner() {
        view.viewWithTag(ostSpinnerTag)?.removeFromSuperview()
    }
}
