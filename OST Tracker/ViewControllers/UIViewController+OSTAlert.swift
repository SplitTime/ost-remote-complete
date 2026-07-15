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

    /// Shared logout flow used everywhere a "Log out" action appears. Verifies the
    /// connection first, then confirms: when reachable, a plain confirmation; when
    /// not, a blocking warning that still offers an override, so a user with a dead
    /// connection is never permanently stuck logged in.
    func ostPresentLogoutFlow() {
        let checking = UIAlertController(title: "Checking connection…", message: "\n\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .gray)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        checking.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: checking.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: checking.view.bottomAnchor, constant: -16)
        ])
        present(checking, animated: true)

        OSTBackend.shared.verifyConnection { [weak self] error in
            guard let self = self else { return }
            checking.dismiss(animated: true) {
                self.ostPresentLogoutConfirmation(reachable: error == nil)
            }
        }
    }

    private func ostPresentLogoutConfirmation(reachable: Bool) {
        let alert = UIAlertController(
            title: reachable ? "Are you sure you would like to log out?" : "Can't reach OpenSplitTime",
            message: reachable
                ? "You can log back in using your current connection, but you won't be able to add entries or log back in if you lose it."
                : "You will not be able to log back in or add entries until you have a data connection again.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: reachable ? "Logout" : "Log Out Anyway", style: .destructive) { _ in
            AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
            AppDelegate.getInstance()?.logout()
        })
        present(alert, animated: true)
    }
}
