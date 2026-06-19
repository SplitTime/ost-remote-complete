//
//  UIViewController+OSTAlert.swift
//  OST Tracker
//
//  Shared native replacement for the old OHAlertView single-button alerts used
//  across the migrated Swift screens.
//

import UIKit

extension UIViewController {
    /// Simple informational alert with a single "Ok" dismiss button.
    func ostPresentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel))
        present(alert, animated: true)
    }
}
