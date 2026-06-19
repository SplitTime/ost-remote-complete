//
//  OSTAboutViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 1). Keeps the existing XIB; the custom class
//  still resolves to "OSTAboutViewController" via @objc.
//

import UIKit
import MFSideMenu

@objc(OSTAboutViewController)
class OSTAboutViewController: OSTBaseViewController {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var targetLbl: UILabel!
    @IBOutlet weak var versionLbl: UILabel!
    @IBOutlet weak var primaryLbl: UILabel!
    @IBOutlet weak var fallBackLbl: UILabel!

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostApplySafeAreaFix()
        ostPositionBadgeAtMenu()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let info = Bundle.main.infoDictionary
        targetLbl.text = info?["CFBundleName"] as? String
        versionLbl.text = "Version: 3.1.1"
        if let primary = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") {
            primaryLbl.text = "Primary: \(primary)"
        }
        if let fallback = Bundle.main.object(forInfoDictionaryKey: "BACKEND_ALTERNATE_URL") {
            fallBackLbl.text = "Fallback: \(fallback)"
        }
    }

    @IBAction func onMenu(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @IBAction func onReturnToLiveEntry(_ sender: Any) {
        AppDelegate.getInstance()?.showTracker()
    }
}
