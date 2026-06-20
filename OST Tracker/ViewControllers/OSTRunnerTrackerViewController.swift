//
//  OSTRunnerTrackerViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 2). The app's core bib-entry screen. Keeps the
//  XIB (@objc), the Obj-C APNumberPad, OSTSound, OSTRunnerBadge and MagicalRecord
//  via bridging, and the UIView+Additions frame helpers (.top/.width/.centerX…).
//  Dropped the dead iPhone-5/6P/X/XR exact-height layout hacks (none fire on the
//  iPhone 7 / iPad mini fleet or modern sims); the iPad block + the generic
//  safe-area shift are preserved.
//
//  The bib field is watched via KVO on `text` because APNumberPad mutates the text
//  programmatically (a target/action editingChanged event would not fire).
//

import UIKit
import CoreData

@objc(OSTRunnerTrackerViewController)
class OSTRunnerTrackerViewController: OSTBaseViewController, UITextFieldDelegate {

    @IBOutlet weak var txtBibNumber: UITextField!
    @IBOutlet weak var numberPadContainerView: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblTime: UILabel!
    @IBOutlet weak var btnLeft: UIButton!
    @IBOutlet weak var btnRight: UIButton!
    @IBOutlet weak var pacerAndAidView: UIView!
    @IBOutlet weak var btnRightMenu: UIButton!
    @IBOutlet weak var lblPersonAdded: UILabel!
    @IBOutlet weak var lblOutTimeBadge: UILabel!
    @IBOutlet weak var lblInTimeBadge: UILabel!
    @IBOutlet weak var lblRunnerInfo: UILabel!
    @IBOutlet weak var lblAdded: UILabel!
    @IBOutlet weak var btnStopped: UIButton!
    @IBOutlet weak var btnPacer: UIButton!
    @IBOutlet weak var headerContainerView: UIView!
    // Not wired in the XIB (was a silently-nil outlet in Obj-C) — keep optional so
    // the .isHidden calls stay no-ops instead of crashing on an implicit unwrap.
    @IBOutlet weak var lblWithPacer: UILabel?
    @IBOutlet weak var lblSecondaryInfo: UILabel!
    @IBOutlet weak var timeContainerView: UIView?
    @IBOutlet weak var separatoryLine: UIView!
    @IBOutlet weak var lblTimeOfTheDay: UILabel!
    @IBOutlet weak var runnerBadge: OSTRunnerBadge!

    private var timer: Timer?
    private var dayString = ""
    private var racer: EffortModel?
    private var entryDateTime: Date?
    private var lastEntry: EntryModel?
    private var leftBitKey: String?
    private var rightBitKey: String?
    private var didApplySafeAreaShift = false

    private static let didRegisterBibNotification = Notification.Name("OSTRunnerTrackerViewControllerDidRegisterBibNotification")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
                                     selector: #selector(onTick(_:)), userInfo: nil, repeats: true)

        btnLeft.titleLabel?.textAlignment = .center
        btnRight.titleLabel?.textAlignment = .center

        lblInTimeBadge.removeFromSuperview()
        lblOutTimeBadge.removeFromSuperview()
        btnLeft.addSubview(lblInTimeBadge)
        btnRight.addSubview(lblOutTimeBadge)

        lblInTimeBadge.top = 0
        lblInTimeBadge.right = btnLeft.width
        lblOutTimeBadge.top = 0
        lblOutTimeBadge.right = btnRight.width

        if UIDevice.current.userInterfaceIdiom == .pad {
            numberPadContainerView.height = view.height / 2
            numberPadContainerView.top = view.height / 2

            headerContainerView.height = 210
            pacerAndAidView.top = headerContainerView.bottom
            txtBibNumber.font = UIFont(name: "Helvetica Bold", size: 75)
            btnLeft.top = pacerAndAidView.bottom + 10
            btnRight.top = pacerAndAidView.bottom + 10
            btnLeft.height = 143
            btnRight.height = 143

            btnLeft.titleLabel?.font = UIFont(name: "Helvetica Bold", size: 33)
            btnRight.titleLabel?.font = UIFont(name: "Helvetica Bold", size: 33)
            lblPersonAdded.font = UIFont(name: "Helvetica Bold", size: 36)
            lblRunnerInfo.font = lblPersonAdded.font
            lblAdded.font = UIFont(name: "Helvetica", size: 28)
            lblSecondaryInfo.font = UIFont(name: "Helvetica", size: 28)
            lblAdded.top = lblAdded.top + 12
            lblTime.font = UIFont(name: "Helvetica Bold", size: 36)
            txtBibNumber.font = UIFont(name: "Helvetica Bold", size: 100)
            lblTimeOfTheDay.font = UIFont(name: "Helvetica Bold", size: 20)
            separatoryLine.right += 50
            lblTimeOfTheDay.width += 30
            lblTimeOfTheDay.height += 6
            lblTimeOfTheDay.top -= 10
            lblTimeOfTheDay.left += 5
            lblTime.width += 50
            txtBibNumber.width += 50
            lblTime.height += 15
            btnPacer.width = 174
            btnStopped.width = 174
            btnPacer.height = 56
            btnStopped.height = 56
            lblSecondaryInfo.top -= 50
            lblSecondaryInfo.height += 30
        }

        let numberPad = NumberPadView()
        numberPad.frame = numberPadContainerView.bounds
        numberPad.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        numberPadContainerView.addSubview(numberPad)
        numberPad.attach(to: txtBibNumber)

        lblOutTimeBadge.layer.cornerRadius = lblOutTimeBadge.width / 2
        lblInTimeBadge.layer.cornerRadius = lblInTimeBadge.width / 2
        lblOutTimeBadge.clipsToBounds = true
        lblInTimeBadge.clipsToBounds = true
        lblOutTimeBadge.isHidden = true
        lblInTimeBadge.isHidden = true

        btnLeft.setBackgroundImage(UIImage(named: "GrayButton"), for: .highlighted)
        btnRight.setBackgroundImage(UIImage(named: "GrayButton"), for: .highlighted)

        txtBibNumber.addObserver(self, forKeyPath: "text", options: [.new, .old], context: nil)
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySafeAreaShiftIfNeeded()
        runnerBadge.width = min(0.58 * view.width, 350)
        runnerBadge.centerX = lblPersonAdded.centerX
        runnerBadge.adjustFontSizes()
    }

    // This XIB predates safe-area layout: the header bar sat at y=0, so "Menu" and
    // the bib display bled under the Dynamic Island. One-time fix: shift all content
    // (except the bottom number pad) down by the extra top inset, and grow the header
    // to fill behind the status bar with its own content pushed below the island.
    private func applySafeAreaShiftIfNeeded() {
        if didApplySafeAreaShift { return }
        let inset = view.safeAreaInsets.top - 20.0 // old design assumed a 20pt status bar
        if inset <= 0.5 { return }                 // legacy devices (iPad mini 2/3 etc.)
        didApplySafeAreaShift = true

        for sub in view.subviews {
            if sub == numberPadContainerView || sub == headerContainerView { continue }
            sub.frame.origin.y += inset
        }
        headerContainerView.frame.size.height += inset
        for child in headerContainerView.subviews {
            child.frame.origin.y += inset
        }
    }

    @objc func onTick(_ timer: Timer) {
        let date = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        lblTime.text = timeFormatter.string(from: date)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayString = dayFormatter.string(from: date)

        entryDateTime = date
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
        lblTitle.text = CurrentCourse.getCurrentCourse()?.splitName

        btnLeft.width = view.width / 2 - 4
        btnRight.width = view.width / 2 - 4
        btnLeft.left = 0
        btnRight.right = view.width

        let entries = (CurrentCourse.getCurrentCourse()?.splitAttributes as? [String: Any])?["entries"] as? [[String: Any]] ?? []
        let splitEntriesIn = entries.filter { ($0["subSplitKind"] as? String) == "in" }
        let splitEntriesOut = entries.filter { ($0["subSplitKind"] as? String) == "out" }

        if splitEntriesIn.count == 1 && splitEntriesOut.count == 0 {
            btnLeft.width = btnRight.right - btnLeft.left
            btnRight.isHidden = true
            btnLeft.setTitle(splitEntriesIn[0]["label"] as? String, for: .normal)
            leftBitKey = "in"
        }
        if splitEntriesIn.count == 0 && splitEntriesOut.count == 1 {
            btnRight.width = btnRight.right - btnLeft.left
            btnLeft.isHidden = true
            btnRight.left = btnLeft.left
            rightBitKey = "out"
            btnRight.setTitle(splitEntriesOut[0]["label"] as? String, for: .normal)
        } else if splitEntriesIn.count == 1 && splitEntriesOut.count == 1 {
            btnRight.isHidden = false
            btnLeft.isHidden = false
            btnLeft.width = view.width / 2 - 4
            btnRight.width = view.width / 2 - 4
            btnLeft.left = 0
            btnRight.right = view.width
            btnLeft.setTitle(splitEntriesIn[0]["label"] as? String, for: .normal)
            btnRight.setTitle(splitEntriesOut[0]["label"] as? String, for: .normal)
            leftBitKey = "in"
            rightBitKey = "out"
        } else if splitEntriesIn.count == 2 {
            btnRight.isHidden = false
            btnLeft.isHidden = false
            btnLeft.width = view.width / 2 - 4
            btnRight.width = view.width / 2 - 4
            btnLeft.left = 0
            btnRight.right = view.width
            btnLeft.setTitle(splitEntriesIn[0]["label"] as? String, for: .normal)
            btnRight.setTitle(splitEntriesIn[1]["label"] as? String, for: .normal)
            leftBitKey = "in"
            rightBitKey = "in"
        } else if splitEntriesOut.count == 2 {
            btnRight.isHidden = false
            btnLeft.isHidden = false
            btnLeft.width = view.width / 2 - 4
            btnRight.width = view.width / 2 - 4
            btnLeft.left = 0
            btnRight.right = view.width
            btnLeft.setTitle(splitEntriesOut[0]["label"] as? String, for: .normal)
            btnRight.setTitle(splitEntriesOut[1]["label"] as? String, for: .normal)
            leftBitKey = "out"
            rightBitKey = "out"
        }

        if CurrentCourse.getCurrentCourse()?.monitorPacers?.boolValue != true {
            lblWithPacer?.isHidden = true
            btnPacer.isHidden = true
            btnStopped.center = CGPoint(x: pacerAndAidView.width / 2, y: pacerAndAidView.height / 2)
        } else {
            lblWithPacer?.isHidden = false
            btnPacer.isHidden = false
            btnStopped.center = CGPoint(x: pacerAndAidView.width / 4, y: pacerAndAidView.height / 2)
            btnPacer.center = CGPoint(x: pacerAndAidView.width / 4 * 3, y: pacerAndAidView.height / 2)
        }

        if UIApplication.shared.statusBarOrientation.isLandscape {
            btnLeft.width = view.height / 2.7
            btnRight.width = view.height / 2.7
            btnLeft.left = 10
            btnLeft.top = view.width / 2.5
            btnRight.right = view.right - 10
            btnRight.top = btnLeft.top
        }
    }

    // MARK: - Actions

    @IBAction func onRight(_ sender: Any) {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    @objc func cleanData() {
        lastEntry = nil
        runnerBadge.isHidden = true
        lblAdded.isHidden = true
        lblRunnerInfo.isHidden = true
        btnPacer.isSelected = false
        btnStopped.isSelected = false
        txtBibNumber.text = nil
        lblInTimeBadge.isHidden = true
        lblOutTimeBadge.isHidden = true
    }

    @IBAction func onEntryButton(_ sender: Any) {
        txtBibNumber.removeObserver(self, forKeyPath: "text")
        UIDevice.current.playInputClick()

        lblOutTimeBadge.isHidden = true
        lblInTimeBadge.isHidden = true
        guard let course = CurrentCourse.getCurrentCourse(),
              let entry = EntryModel.mr_createEntity() as? EntryModel else { return }

        if txtBibNumber.text?.isEmpty ?? true {
            entry.bibNumber = "-1"
            racer = nil
        } else {
            entry.bibNumber = txtBibNumber.text
        }
        entry.bitKey = ((sender as? UIButton) == btnLeft) ? leftBitKey : rightBitKey

        let tzOffset = TimeZone.current.secondsFromGMT() / 60 / 60
        let sign = tzOffset < 0 ? "" : "+"
        entry.absoluteTime = String(format: "%@ %@\(sign)%02d:00", dayString, lblTime.text ?? "", tzOffset)
        entry.displayTime = lblTime.text
        entry.withPacer = btnPacer.isSelected ? "true" : "false"
        entry.stoppedHere = btnStopped.isSelected ? "true" : "false"
        entry.courseName = course.eventName
        entry.splitName = course.splitName
        entry.combinedCourseId = course.eventId

        for dict in (course.dataEntryGroups as? [[String: Any]]) ?? [] {
            if (dict["title"] as? String) == course.splitName {
                let subEntries = dict["entries"] as? [[String: Any]] ?? []
                let tag = (sender as? UIView)?.tag ?? 0
                if tag == 1 {
                    entry.entryCourseId = racer?.eventId?.stringValue
                    entry.splitName = subEntries[0]["splitName"] as? String
                } else if tag == 2 {
                    entry.entryCourseId = racer?.eventId?.stringValue
                    entry.splitName = subEntries[1]["splitName"] as? String
                }
            }
        }

        entry.entryTime = entryDateTime
        entry.timeEntered = Date()
        if let racer = racer { entry.fullName = racer.fullName }
        entry.source = "ost-remote-\(OSTSessionManager.getUUIDString() ?? "")"

        saveContext()

        lblRunnerInfo.isHidden = true
        lblAdded.isHidden = false
        lblPersonAdded.isHidden = false

        var entryName = entry.fullName
        let bibFound = !(entryName?.isEmpty ?? true)
        if !bibFound {
            entryName = "Bib not found"
            OSTSound.shared().play("ost-remote-bib-not-found")
        } else {
            if racer?.checkIfEffortShouldBe(inSplit: CurrentCourse.getCurrentCourse()?.splitName) == true {
                OSTSound.shared().play("click")
            } else {
                OSTSound.shared().play("ost-remote-bib-wrong-event-1")
            }
        }

        NotificationCenter.default.post(name: Self.didRegisterBibNotification, object: nil)

        lblPersonAdded.text = entryName ?? ""
        lblAdded.text = racer?.flexibleGeolocation ?? ""
        lastEntry = entry
        runnerBadge.isHidden = false
        runnerBadge.update(with: runnerBadgeViewModel(racer: racer, time: lblTime.text, bibNumber: txtBibNumber.text))
        lblAdded.text = ""
        lblSecondaryInfo.text = ""

        txtBibNumber.text = ""
        btnPacer.isSelected = false
        btnStopped.isSelected = false
        txtBibNumber.addObserver(self, forKeyPath: "text", options: [.new, .old], context: nil)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            return false
        }
        let current = (textField.text ?? "") as NSString
        // Prevent crashing undo bug
        if range.length + range.location > current.length {
            return false
        }
        let newLength = current.length + (string as NSString).length - range.length
        let accepted = newLength <= 4
        if !accepted {
            OSTSound.shared().play("ost-remote-keypress-negative")
        }
        return accepted
    }

    @IBAction func onRunnerInfo(_ sender: Any) {
        guard let lastEntry = lastEntry else { return }
        let editVC = OSTEditEntryViewController(nibName: nil, bundle: nil)
        present(editVC, animated: true)

        editVC.entryHasBeenDeletedBlock = { [weak self] in
            guard let self = self else { return }
            self.lastEntry = nil
            self.runnerBadge.isHidden = true
            self.lblAdded.isHidden = true
            self.lblPersonAdded.text = "Enter Bib Number"
            self.lblRunnerInfo.text = ""
            self.lblSecondaryInfo.text = ""
            self.lblAdded.text = ""
            let red = UIColor(red: 159.0/255, green: 34.0/255, blue: 40.0/255, alpha: 1)
            self.lblRunnerInfo.textColor = red
            self.txtBibNumber.textColor = red
        }
        editVC.entryHasBeenUpdatedBlock = { [weak self] effort in
            guard let self = self else { return }
            let entryName = self.lastEntry?.fullName
            self.lblPersonAdded.text = (entryName?.isEmpty ?? true) ? "Bib not found" : effort?.fullName
            self.runnerBadge.update(with: self.runnerBadgeViewModel(racer: effort,
                                                                         time: self.lastEntry?.displayTime,
                                                                         bibNumber: self.lastEntry?.bibNumber))
        }
        editVC.configure(withEntry: lastEntry)
    }

    @IBAction func onButtonPacer(_ sender: Any) {
        btnPacer.isSelected.toggle()
        OSTSound.shared().play("ost-remote-switch-1")
    }

    @IBAction func onBtnStopped(_ sender: Any) {
        btnStopped.isSelected.toggle()
        OSTSound.shared().play("ost-remote-switch-1")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        updateBibInfo()
    }

    private func updateBibInfo() {
        lblRunnerInfo.isHidden = false
        lastEntry = nil
        runnerBadge.isHidden = true
        lblAdded.isHidden = true
        lblOutTimeBadge.isHidden = true
        lblInTimeBadge.isHidden = true
        racer = nil
        lblRunnerInfo.textColor = .darkGray
        txtBibNumber.textColor = .black

        let bib = txtBibNumber.text ?? ""
        if bib.isEmpty {
            lblPersonAdded.text = "Enter Bib Number"
            lblRunnerInfo.text = ""
            lblSecondaryInfo.text = ""
            lblAdded.text = ""
            return
        }

        let effort = EffortModel.mr_findFirst(with: NSPredicate(format: "bibNumber == %@", NSDecimalNumber(string: bib))) as? EffortModel

        guard let racer = effort else {
            lblRunnerInfo.text = "Bib Not Found"
            let red = UIColor(red: 159.0/255, green: 34.0/255, blue: 40.0/255, alpha: 1)
            lblRunnerInfo.textColor = red
            txtBibNumber.textColor = red
            lblPersonAdded.text = ""
            lblSecondaryInfo.text = ""
            return
        }

        self.racer = racer
        lblAdded.isHidden = false
        lblPersonAdded.text = racer.fullName
        lblAdded.text = racer.flexibleGeolocation
        lblRunnerInfo.text = ""

        var secondaryInfo = ""
        if let shortName = effortEventShortName(racer) { secondaryInfo += "\(shortName)\n" }
        if let gender = racer.gender { secondaryInfo += gender.capitalized }
        if let age = racer.age {
            secondaryInfo += (racer.gender != nil) ? " (\(age))" : "\(age)"
        }
        lblSecondaryInfo.text = secondaryInfo

        let course = CurrentCourse.getCurrentCourse()
        let multiLap = course?.multiLap?.boolValue ?? false

        func entryCount(bitKey: String?, splitName: String?) -> Int {
            EntryModel.mr_findAll(with: NSPredicate(format: "bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",
                                                    bitKey ?? "", bib, course?.eventId ?? "", splitName ?? ""))?.count ?? 0
        }

        if entryCount(bitKey: leftBitKey, splitName: course?.splitName) > 0 {
            lblInTimeBadge.isHidden = false
            lblInTimeBadge.text = multiLap ? "\(entryCount(bitKey: leftBitKey, splitName: course?.splitName))" : "!"
        }
        if entryCount(bitKey: leftBitKey, splitName: btnLeft.titleLabel?.text) > 0 {
            lblInTimeBadge.isHidden = false
            lblInTimeBadge.text = multiLap ? "\(entryCount(bitKey: leftBitKey, splitName: btnLeft.titleLabel?.text))" : "!"
        }
        if entryCount(bitKey: rightBitKey, splitName: course?.splitName) > 0 {
            lblOutTimeBadge.isHidden = false
            lblOutTimeBadge.text = multiLap ? "\(entryCount(bitKey: rightBitKey, splitName: course?.splitName))" : "!"
        }
        if entryCount(bitKey: rightBitKey, splitName: btnRight.titleLabel?.text) > 0 {
            lblOutTimeBadge.isHidden = false
            lblOutTimeBadge.text = multiLap ? "\(entryCount(bitKey: rightBitKey, splitName: btnRight.titleLabel?.text))" : "!"
        }
    }

    private func effortEventShortName(_ effort: EffortModel) -> String? {
        let key = effort.eventId?.stringValue ?? ""
        return (CurrentCourse.getCurrentCourse()?.eventShortNames as? [String: String])?[key]
    }

    deinit {
        txtBibNumber?.removeObserver(self, forKeyPath: "text")
    }

    // MARK: - Rotation

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if UIApplication.shared.statusBarOrientation.isPortrait {
            btnLeft.width = view.width / 2.7
            btnRight.width = view.width / 2.7
            btnLeft.left = 10
            btnLeft.top = view.height / 2.5
            btnRight.right = view.right - 10
            btnRight.top = btnLeft.top
        } else {
            btnLeft.top = pacerAndAidView.bottom + 10
            btnRight.top = pacerAndAidView.bottom + 10
            btnRight.right = view.right
            btnLeft.left = view.left
            btnLeft.height = 143
            btnRight.height = 143
            if btnRight.isHidden || btnLeft.isHidden {
                btnLeft.width = view.height
                btnRight.width = view.height
            } else {
                btnLeft.width = view.height / 2 - 4
                btnRight.width = view.height / 2 - 4
            }
        }
    }

    // MARK: - Helpers

    private func runnerBadgeViewModel(racer: EffortModel?, time: String?, bibNumber: String?) -> OSTRunnerBadgeViewModel {
        let viewModel = OSTRunnerBadgeViewModel()
        viewModel.bibNumber = bibNumber ?? ""
        viewModel.time = time ?? ""
        var caption = ""
        if let gender = racer?.gender { caption += gender.capitalized }
        if let age = racer?.age {
            caption += (racer?.gender != nil) ? " (\(age))" : "\(age)"
        }
        viewModel.caption = caption
        return viewModel
    }

    private func saveContext() {
        NSManagedObjectContext.mr_default().processPendingChanges()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
    }
}
