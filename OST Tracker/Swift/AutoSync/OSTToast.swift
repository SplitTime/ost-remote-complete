//
//  OSTToast.swift
//  OST Tracker
//
//  Native sync-completion toast, ported verbatim from the old OSTSyncManager.m
//  (`showToastIfAppropriateWithErrors:`). A rounded label fades in at the top of
//  the key window, auto-dismisses after 3s, and dismisses on tap. Same colors.
//

import UIKit

@objc(OSTToast)
final class OSTToast: NSObject {

    /// Green "synced successfully" on success, red "failed to sync" otherwise.
    @objc static func show(success: Bool) {
        guard let window = AppDelegate.getInstance()?.window else { return }

        let message = success ? "Times synced successfully." : "Failed to sync times."
        let bg = success
            ? UIColor(red: 88/255, green: 182/255, blue: 73/255, alpha: 1)
            : UIColor(red: 247/255, green: 45/255, blue: 0, alpha: 1)

        DispatchQueue.main.async {
            let toast = UILabel()
            toast.text = message
            toast.textColor = .black
            toast.textAlignment = .center
            toast.numberOfLines = 0
            toast.backgroundColor = bg
            toast.font = .systemFont(ofSize: 16)
            toast.layer.cornerRadius = 10
            toast.clipsToBounds = true
            toast.isUserInteractionEnabled = true
            toast.addGestureRecognizer(UITapGestureRecognizer(target: toast, action: #selector(UIView.removeFromSuperview)))

            let maxWidth = window.bounds.size.width - 40
            let fit = toast.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
            let w = min(fit.width + 30, maxWidth)
            let h = fit.height + 20
            let top = window.safeAreaInsets.top + 10
            toast.frame = CGRect(x: (window.bounds.size.width - w) / 2, y: top, width: w, height: h)
            toast.alpha = 0
            window.addSubview(toast)

            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 1 }) { _ in
                UIView.animate(withDuration: 0.3, delay: 3.0, options: [], animations: { toast.alpha = 0 }) { _ in
                    toast.removeFromSuperview()
                }
            }
        }
    }
}
