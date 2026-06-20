//
//  OSTEditEntryViewController.swift
//  OST Tracker
//
//  Migrated from Objective-C (Phase 2.5). Edit/create-entry screen shared by
//  Review/Sync and the runner tracker. Keeps the XIB (@objc) and the Obj-C
//  APNumberPad / CustomUIDatePicker / OSTSound / MagicalRecord via bridging.
//
//  Fixes folded in during the port:
//   - IQKeyboardManager `enableAutoToolbar` was YES, which floated a stray Done
//     bar over the APNumberPad ("weird" toolbar) — turned off (the time field has
//     its own Done/Cancel accessory; the bib field uses the number pad).
//   - Dropped the dead iPhone-X/XR-only +7pt nudge.
//   - `lblWithPacer` is declared but NOT wired in the XIB (silently nil in Obj-C) —
//     made optional so Swift doesn't crash on the implicit unwrap.
//   - OHAlertView delete confirm -> native UIAlertController.
//

import UIKit
import CoreData

@objc(OSTEditEntryViewController)
class OSTEditEntryViewController: UIViewController {

    // MARK: - Public (set by Review/Sync + tracker)
    @objc var creatingNew = false
    @objc var entryHasBeenDeletedBlock: (() -> Void)?
    @objc var entryHasBeenUpdatedBlock: ((EffortModel?) -> Void)?

    // MARK: - Outlets
    @IBOutlet weak var txtBibNumber: UITextField!
    @IBOutlet weak var swchPacer: UIButton!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblRunner: UILabel!
    @IBOutlet weak var swchStoppedHere: UIButton!
    @IBOutlet weak var txtDate: OSTDropDownField!
    @IBOutlet weak var pacerAndAidView: UIView!
    @IBOutlet weak var txtTime: UITextField!
    @IBOutlet weak var btnDelete: UIButton!
    @IBOutlet weak var btnUpdate: UIButton!
    @IBOutlet weak var btnRightMenu: UIButton!
    // Not wired in the XIB — optional so the .isHidden calls stay no-ops.
    @IBOutlet weak var lblWithPacer: UILabel?

    // MARK: - State
    private var entry: EntryModel?
    private var effort: EffortModel?
    private var customPicker: CustomUIDatePicker!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        txtDate.dropDownMode = .datePicker
        // IQDropDownTextField wires a UIDatePicker as its inputView; on iOS 14+ that
        // defaults to the compact "pill" style, which renders as a near-empty gray
        // area in a keyboard-height input view. Force the classic wheels so it fills.
        if #available(iOS 13.4, *) {
            (txtDate.inputView as? UIDatePicker)?.preferredDatePickerStyle = .wheels
        }

        customPicker = CustomUIDatePicker(frame: CGRect(x: 0, y: 0, width: view.width, height: 200))
        txtTime.inputView = customPicker

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(onDoneSelectedTime(_:))),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(onDoneSelectedTime(_:)))
        ]
        txtTime.inputAccessoryView = toolbar

        txtTime.removeInputAssistant()
        txtBibNumber.removeInputAssistant()
        txtDate.removeInputAssistant()

        if creatingNew {
            btnDelete.isHidden = true
            btnUpdate.left = 0
            btnUpdate.width = view.width
            btnUpdate.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin]
            btnUpdate.setTitle("Create new entry", for: .normal)
        }

        let numberPad = NumberPadView()
        numberPad.attach(to: txtBibNumber)
        txtBibNumber.inputView = numberPad

        pacerAndAidView.height = 70

        let showPacer = CurrentCourse.getCurrentCourse()?.monitorPacers?.boolValue ?? false
        lblWithPacer?.isHidden = !showPacer
        swchPacer.isHidden = !showPacer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let viewCenter = view.width * 0.5
        let switchSeparation: CGFloat = 80
        if swchPacer.isHidden {
            swchStoppedHere.centerX = viewCenter
        } else {
            swchStoppedHere.centerX = viewCenter - switchSeparation
            swchPacer.centerX = viewCenter + switchSeparation
        }
    }

    @objc func onDoneSelectedTime(_ sender: Any?) {
        txtTime.resignFirstResponder()
    }

    // MARK: - Actions

    @IBAction func onBibNumber(_ sender: Any) {
        txtBibNumber.becomeFirstResponder()
    }

    @IBAction func onTime(_ sender: Any) {
        txtDate.becomeFirstResponder()
    }

    @IBAction func onEditTime(_ sender: Any) {
        txtTime.becomeFirstResponder()
    }

    @IBAction func timeEndEditing(_ sender: Any) {
        txtTime.text = String(format: "%02ld:%02ld:%02ld", customPicker.hours, customPicker.mins, customPicker.secs)
    }

    @IBAction func onSwitch(_ sender: UIButton) {
        sender.isSelected.toggle()
        OSTSound.shared().play("ost-remote-switch-1")
    }

    @IBAction func onClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func onDelete(_ sender: Any) {
        let alert = UIAlertController(title: "This action cannot be undone.",
                                      message: "Are you sure you want to delete this Entry?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.entry?.mr_deleteEntity()
            self.saveContext()
            self.dismiss(animated: true)
            self.entryHasBeenDeletedBlock?()
        })
        present(alert, animated: true)
    }

    @IBAction func onUpdate(_ sender: Any) {
        if creatingNew {
            guard let source = entry, let newEntry = EntryModel.mr_createEntity() as? EntryModel else { return }

            newEntry.bibNumber = (txtBibNumber.text?.isEmpty ?? true) ? "-1" : txtBibNumber.text
            newEntry.bitKey = source.bitKey
            newEntry.splitId = source.splitId
            newEntry.courseName = source.courseName
            newEntry.splitName = source.splitName
            newEntry.entryCourseId = source.entryCourseId
            newEntry.combinedCourseId = source.combinedCourseId

            onDoneSelectedTime(nil)
            if !(txtBibNumber.text?.isEmpty ?? true) { newEntry.bibNumber = txtBibNumber.text }
            populateTimeAndFlags(newEntry)
            newEntry.source = source.source

            entryHasBeenUpdatedBlock?(effort)
            saveContext()
            dismiss(animated: true)
            return
        }

        guard let existing = entry else { return }
        onDoneSelectedTime(nil)
        if !(txtBibNumber.text?.isEmpty ?? true) { existing.bibNumber = txtBibNumber.text }
        populateTimeAndFlags(existing)

        saveContext()
        dismiss(animated: true)
        entryHasBeenUpdatedBlock?(effort)
    }

    @IBAction func onBibNumberChanged(_ sender: Any?) {
        lblRunner.textColor = .darkGray
        guard let bib = txtBibNumber.text, !bib.isEmpty else {
            lblRunner.text = ""
            return
        }
        if let found = EffortModel.mr_findFirst(with: NSPredicate(format: "bibNumber == %@", NSDecimalNumber(string: bib))) as? EffortModel {
            lblRunner.text = "Bib Found: \(found.fullName ?? "")"
            effort = found
        } else {
            lblRunner.text = "Bib Not Found!"
            lblRunner.textColor = .red
            effort = nil
        }
    }

    // MARK: - Configuration

    @objc func configure(withEntry entry: EntryModel) {
        self.entry = entry

        if entry.bibNumber != "-1" {
            txtBibNumber.text = entry.bibNumber
            txtBibNumber.selectedTextRange = txtBibNumber.textRange(from: txtBibNumber.endOfDocument, to: txtBibNumber.endOfDocument)
        }
        lblTitle.text = entry.courseName
        swchPacer.isSelected = (entry.withPacer as NSString?)?.boolValue ?? false
        swchStoppedHere.isSelected = (entry.stoppedHere as NSString?)?.boolValue ?? false

        txtDate.date = entry.entryTime ?? Date()

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: entry.entryTime ?? Date())
        customPicker.hours = components.hour ?? 0
        customPicker.mins = components.minute ?? 0
        customPicker.secs = components.second ?? 0
        customPicker.selectRowsInPicker()
        txtTime.text = String(format: "%02ld:%02ld:%02ld", components.hour ?? 0, components.minute ?? 0, components.second ?? 0)

        onBibNumberChanged(nil)
    }

    // MARK: - Helpers

    private func populateTimeAndFlags(_ entry: EntryModel) {
        entry.fullName = effort?.fullName
        entry.entryTime = txtDate.date.addingTimeInterval(Double(customPicker.getTimeInMS() / 1000))
        entry.displayTime = txtTime.text

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayString = formatter.string(from: txtDate.date)
        let tzOffset = TimeZone.current.secondsFromGMT() / 60 / 60
        let sign = tzOffset < 0 ? "" : "+"
        entry.absoluteTime = String(format: "%@ %@\(sign)%02d:00", dayString, txtTime.text ?? "", tzOffset)

        entry.withPacer = swchPacer.isSelected ? "true" : "false"
        entry.stoppedHere = swchStoppedHere.isSelected ? "true" : "false"
    }

    private func saveContext() {
        NSManagedObjectContext.mr_default().processPendingChanges()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
    }
}
