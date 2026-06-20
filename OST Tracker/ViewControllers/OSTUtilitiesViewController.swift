//
//  OSTUtilitiesViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 1). Keeps the existing XIB; OHAlertView
//  replaced with native UIAlertController. Still uses the Obj-C network manager
//  and MagicalRecord via bridging (migrated in later phases).
//

import UIKit
import CoreData

@objc(OSTUtilitiesViewController)
class OSTUtilitiesViewController: OSTBaseViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet var loadingView: UIView!
    @IBOutlet weak var lblYourDataIsSynced: UILabel!
    @IBOutlet weak var imgCheckMark: UIImageView!
    @IBOutlet weak var lblSuccess: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var btnReturnToLiveEntry: UIButton!
    @IBOutlet weak var lblSyncing: UILabel!
    @IBOutlet weak var logoImage: UIImageView!
    @IBOutlet weak var remoteLbl: UILabel!
    @IBOutlet weak var btnRetry: UIButton!

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostApplySafeAreaFix()
        ostPositionBadgeAtMenu()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadingView.frame.size = view.frame.size
    }

    // MARK: - Loading states

    private func showLoadingScreen() {
        showLoadingValues()
        loadingView.frame.size = view.frame.size
        view.addSubview(loadingView)
        view.bringSubviewToFront(loadingView)
        loadingView.alpha = 0
        UIView.animate(withDuration: 0.5) { self.loadingView.alpha = 1 }
    }

    private func showLoadingValues() {
        btnRetry.isHidden = true
        imgCheckMark.isHidden = true
        lblSuccess.isHidden = true
        lblYourDataIsSynced.isHidden = true
        btnReturnToLiveEntry.isHidden = true
        activityIndicator.startAnimating()
        progressBar.isHidden = false
        logoImage.isHidden = false
        remoteLbl.isHidden = false
    }

    private func showFinishLoadingValues() {
        imgCheckMark.image = UIImage(named: "CheckMark")
        imgCheckMark.isHidden = false
        lblSuccess.text = "Success!"
        lblSuccess.isHidden = false
        lblYourDataIsSynced.text = "The entrants data has been updated"
        lblYourDataIsSynced.isHidden = false
        btnReturnToLiveEntry.isHidden = false
        activityIndicator.stopAnimating()
        lblSyncing.isHidden = true
        progressBar.isHidden = true
        logoImage.isHidden = true
        remoteLbl.isHidden = true
    }

    private func showFinishLoadingErrorValues(_ error: String) {
        imgCheckMark.image = UIImage(named: "Error-icon")
        imgCheckMark.isHidden = false
        lblSuccess.text = "Failure!"
        lblSuccess.isHidden = false
        lblYourDataIsSynced.text = error
        lblYourDataIsSynced.isHidden = false
        btnReturnToLiveEntry.isHidden = false
        btnRetry.isHidden = false
        activityIndicator.stopAnimating()
        lblSyncing.isHidden = true
        progressBar.isHidden = true
        logoImage.isHidden = true
        remoteLbl.isHidden = true
    }

    // MARK: - Actions

    @IBAction func onRefreshData(_ sender: Any) {
        showLoadingScreen()
        progressBar.progress = 0.5
        guard let currentCourse = CurrentCourse.getCurrentCourse() else { return }

        OSTBackend.shared.getEventsDetails(currentCourse.eventId ?? "") { [weak self] object, error in
            guard let self = self else { return }
            if let error = error {
                UIView.animate(withDuration: 0.5) { self.showFinishLoadingErrorValues(error.localizedDescription) }
                return
            }
            self.progressBar.progress = 1
            self.activityIndicator.stopAnimating()

            let root = object as? [String: Any]
            let attributes = (root?["data"] as? [String: Any])?["attributes"] as? [String: Any]
            currentCourse.dataEntryGroups = attributes?["dataEntryGroups"]

            let included = root?["included"] as? [[String: Any]] ?? []
            EffortModel.mr_reconcile(fromIncluded: included, ofType: "efforts")
            currentCourse.monitorPacers = attributes?["monitorPacers"] as? NSNumber

            var eventIdsAndSplits = [String: [Any]]()
            var eventShortNames = [String: String]()
            for dict in included where (dict["type"] as? String) == "events" {
                guard let eventId = dict["id"] as? String else { continue }
                let attrs = dict["attributes"] as? [String: Any]
                if let shortName = attrs?["shortName"] as? String {
                    eventShortNames[eventId] = shortName
                }
                var arr = eventIdsAndSplits[eventId] ?? []
                if let psn = attrs?["parameterizedSplitNames"] { arr.append(psn) }
                eventIdsAndSplits[eventId] = arr
            }
            currentCourse.eventIdsAndSplits = eventIdsAndSplits
            currentCourse.eventShortNames = eventShortNames

            UIView.animate(withDuration: 0.5) { self.showFinishLoadingValues() }
            NSManagedObjectContext.mr_default().processPendingChanges()
            NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
        }
    }

    @IBAction func onReturnToLiveEntry(_ sender: Any) {
        activityIndicator.stopAnimating()
        loadingView.isHidden = true
        loadingView.removeFromSuperview()
        AppDelegate.getInstance()?.showTracker()
    }

    @IBAction func onAbout(_ sender: Any) {
        AppDelegate.getInstance()?.showAbout()
    }

    @IBAction func onMenu(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @IBAction func onChangeStation(_ sender: Any) {
        let event = OSTEventSelectionViewController(nibName: nil, bundle: nil)
        event.changeStation = true
        present(event, animated: true)
    }

    @IBAction func onLogout(_ sender: Any) {
        let checking = UIAlertController(title: "Checking connection…",
                                         message: "\n\n",
                                         preferredStyle: .alert)
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
                if error == nil {
                    self.presentLogoutConfirmation()
                } else {
                    self.presentLogoutOverride()
                }
            }
        }
    }

    /// Online: confirm, then log out.
    private func presentLogoutConfirmation() {
        let alert = UIAlertController(title: "Are you sure you would like to log out?",
                                      message: "You can log back in using your current connection, but you won't be able to add entries or log back in if you lose it.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    /// Check failed: block, but allow an immediate override.
    private func presentLogoutOverride() {
        let alert = UIAlertController(title: "Can't reach OpenSplitTime",
                                      message: "You will not be able to log back in or add entries until you have a data connection again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out Anyway", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alert, animated: true)
    }

    private func performLogout() {
        let app = AppDelegate.getInstance()
        app?.rightMenuVC.toggleRightSideMenuCompletion(nil)
        app?.logout()
    }
}
