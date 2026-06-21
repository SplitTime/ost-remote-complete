//
//  OSTEditEntryViewController.swift
//  OST Tracker
//
//  Edit/create-entry screen shared by Review/Sync and the runner tracker.
//
//  Fully programmatic (no XIB): the view hierarchy is built in `loadView()` /
//  `viewDidLoad()` with Auto Layout pinned to the safe area, styled through the
//  shared `Theme` design system (matching `LoginViewController`). All data
//  behavior — bib lookup, `-1` filtering, empty-bib block, time/flag math,
//  create vs update, delete confirm, CoreData save — is preserved verbatim from
//  the prior XIB-based implementation. Only the view construction changed.
//

import UIKit
import CoreData

@objc(OSTEditEntryViewController)
class OSTEditEntryViewController: UIViewController {

    // MARK: - Public (set by Review/Sync + tracker)
    @objc var creatingNew = false
    @objc var entryHasBeenDeletedBlock: (() -> Void)?
    @objc var entryHasBeenUpdatedBlock: ((EffortModel?) -> Void)?

    // MARK: - State
    private var entry: EntryModel?
    private var effort: EffortModel?
    private var customPicker: CustomUIDatePicker!

    // MARK: - Views

    private let scrollView = UIScrollView()

    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✕", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        b.tintColor = Theme.tint
        b.setTitleColor(Theme.tint, for: .normal)
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.title
        l.textColor = Theme.label
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        l.numberOfLines = 1
        return l
    }()

    private let bibField = OSTEditEntryViewController.makeThemedField()
    private let timeField = OSTEditEntryViewController.makeThemedField()
    private let dateField: OSTDropDownField = {
        let f = OSTDropDownField()
        OSTEditEntryViewController.styleField(f)
        return f
    }()

    private let runnerLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Font.field
        l.textColor = Theme.secondaryLabel
        l.numberOfLines = 1
        return l
    }()

    private let switchCard: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.fieldFill
        v.layer.cornerRadius = Theme.Metric.cornerRadius
        v.clipsToBounds = true
        return v
    }()
    private let stoppedRow = SwitchRow(title: "Dropped / Time Cut")
    private let pacerRow = SwitchRow(title: "With pacer")

    private let updateButton = PrimaryButton(title: "Update entry", role: .primary)
    private let deleteButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Delete entry", for: .normal)
        b.setTitleColor(Theme.destructive, for: .normal)
        b.titleLabel?.font = Theme.Font.button
        b.backgroundColor = .clear
        return b
    }()

    // MARK: - Field factory

    private static func makeThemedField() -> UITextField {
        let f = UITextField()
        styleField(f)
        return f
    }

    private static func styleField(_ f: UITextField) {
        f.backgroundColor = Theme.fieldFill
        f.layer.cornerRadius = Theme.Metric.cornerRadius
        f.font = Theme.Font.field
        f.textColor = Theme.label
        f.textAlignment = .center
        // Inset the text so it doesn't hug the rounded corners.
        f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        f.leftViewMode = .always
        f.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        f.rightViewMode = .always
        f.heightAnchor.constraint(equalToConstant: Theme.Metric.fieldHeight).isActive = true
    }

    private func captionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = Theme.Font.caption
        l.textColor = Theme.secondaryLabel
        return l
    }

    private func captionedField(_ caption: String, _ field: UIView) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [captionLabel(caption), field])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    // MARK: - loadView

    override func loadView() {
        let root = UIView()
        root.backgroundColor = Theme.background
        self.view = root

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        root.addSubview(scrollView)

        let guide = root.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        buildHierarchy()
        configureInputViews()
        configureSwitchRows()
        wireActions()

        if creatingNew {
            deleteButton.isHidden = true
            updateButton.setTitle("Create new entry", for: .normal)
        }
    }

    // MARK: - Build

    private func buildHierarchy() {
        // Header row: close button + title.
        let header = UIStackView(arrangedSubviews: [closeButton, titleLabel])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .center
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let hairline = UIView()
        hairline.backgroundColor = Theme.separator
        hairline.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Bib number block.
        let bibBlock = UIStackView(arrangedSubviews: [
            captionLabel("Bib number"), bibField, runnerLabel
        ])
        bibBlock.axis = .vertical
        bibBlock.spacing = 6

        // Time + Date row.
        let timeDate = UIStackView(arrangedSubviews: [
            captionedField("Time", timeField),
            captionedField("Date", dateField),
        ])
        timeDate.axis = .horizontal
        timeDate.spacing = 16
        timeDate.distribution = .fillEqually

        // Switch card.
        buildSwitchCard()

        // Actions.
        let actions = UIStackView(arrangedSubviews: [updateButton, deleteButton])
        actions.axis = .vertical
        actions.spacing = 10
        deleteButton.heightAnchor.constraint(equalToConstant: Theme.Metric.buttonHeight).isActive = true

        let content = UIStackView(arrangedSubviews: [
            header, hairline, bibBlock, timeDate, switchCard, actions
        ])
        content.axis = .vertical
        content.spacing = 22
        content.setCustomSpacing(14, after: header)
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -inset),
            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -inset * 2),
        ])
    }

    private func buildSwitchCard() {
        let showPacer = CurrentCourse.getCurrentCourse()?.monitorPacers?.boolValue ?? false
        pacerRow.isHidden = !showPacer

        let sep = UIView()
        sep.backgroundColor = Theme.separator
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        sep.isHidden = !showPacer

        let rows = UIStackView(arrangedSubviews: [stoppedRow, sep, pacerRow])
        rows.axis = .vertical
        rows.translatesAutoresizingMaskIntoConstraints = false
        switchCard.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: switchCard.topAnchor),
            rows.bottomAnchor.constraint(equalTo: switchCard.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: switchCard.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: switchCard.trailingAnchor),
        ])
    }

    // MARK: - Input views

    private func configureInputViews() {
        // Date field: drop-down date picker, with the iOS 13.4+ wheels fix.
        dateField.dropDownMode = .datePicker
        if #available(iOS 13.4, *) {
            (dateField.inputView as? UIDatePicker)?.preferredDatePickerStyle = .wheels
        }

        // Time field: CustomUIDatePicker (H:M:S). Commits in place as the wheels
        // spin (matching the date field), so it needs no Done/Cancel accessory.
        customPicker = CustomUIDatePicker(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        customPicker.onChange = { [weak self] in self?.updateTimeFieldText() }
        timeField.inputView = customPicker

        // Bib field: number pad.
        let numberPad = NumberPadView()
        numberPad.attach(to: bibField)
        bibField.inputView = numberPad

        timeField.removeInputAssistant()
        bibField.removeInputAssistant()
        dateField.removeInputAssistant()
    }

    private func configureSwitchRows() {
        stoppedRow.valueChanged = { [weak self] _ in
            self?.playSwitchSound()
        }
        pacerRow.valueChanged = { [weak self] _ in
            self?.playSwitchSound()
        }
    }

    private func playSwitchSound() {
        OSTSound.shared().play("ost-remote-switch-1")
    }

    private func wireActions() {
        closeButton.addTarget(self, action: #selector(onClose(_:)), for: .touchUpInside)
        updateButton.addTarget(self, action: #selector(onUpdate(_:)), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(onDelete(_:)), for: .touchUpInside)
        timeField.addTarget(self, action: #selector(timeEndEditing(_:)), for: .editingDidEnd)
        bibField.addTarget(self, action: #selector(onBibNumberChanged(_:)), for: .editingChanged)
    }

    @objc func onDoneSelectedTime(_ sender: Any?) {
        timeField.resignFirstResponder()
    }

    // MARK: - Actions

    @objc func timeEndEditing(_ sender: Any) {
        updateTimeFieldText()
    }

    private func updateTimeFieldText() {
        timeField.text = String(format: "%02ld:%02ld:%02ld", customPicker.hours, customPicker.mins, customPicker.secs)
    }

    @objc func onClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @objc func onDelete(_ sender: Any) {
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

    @objc func onUpdate(_ sender: Any) {
        if creatingNew {
            if !BibEntry.isRecordable(bibField.text) {
                let alert = UIAlertController(title: "Bib Required",
                                              message: "Enter a bib number to create a new entry.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }

            guard let source = entry, let newEntry = EntryModel.mr_createEntity() as? EntryModel else { return }

            newEntry.bibNumber = bibField.text
            newEntry.bitKey = source.bitKey
            newEntry.splitId = source.splitId
            newEntry.courseName = source.courseName
            newEntry.splitName = source.splitName
            newEntry.entryCourseId = source.entryCourseId
            newEntry.combinedCourseId = source.combinedCourseId

            onDoneSelectedTime(nil)
            populateTimeAndFlags(newEntry)
            newEntry.source = source.source

            entryHasBeenUpdatedBlock?(effort)
            saveContext()
            dismiss(animated: true)
            return
        }

        guard let existing = entry else { return }
        onDoneSelectedTime(nil)
        if !(bibField.text?.isEmpty ?? true) { existing.bibNumber = bibField.text }
        populateTimeAndFlags(existing)

        saveContext()
        dismiss(animated: true)
        entryHasBeenUpdatedBlock?(effort)
    }

    @objc func onBibNumberChanged(_ sender: Any?) {
        runnerLabel.textColor = Theme.secondaryLabel
        guard let bib = bibField.text, !bib.isEmpty else {
            runnerLabel.text = ""
            return
        }
        if let found = EffortModel.mr_findFirst(with: NSPredicate(format: "bibNumber == %@", NSDecimalNumber(string: bib))) as? EffortModel {
            runnerLabel.text = "Bib Found: \(found.fullName ?? "")"
            runnerLabel.textColor = Theme.success
            effort = found
        } else {
            runnerLabel.text = "Bib Not Found!"
            runnerLabel.textColor = Theme.destructive
            effort = nil
        }
    }

    // MARK: - Configuration

    @objc func configure(withEntry entry: EntryModel) {
        self.entry = entry
        loadViewIfNeeded()

        if entry.bibNumber != "-1" {
            bibField.text = entry.bibNumber
            bibField.selectedTextRange = bibField.textRange(from: bibField.endOfDocument, to: bibField.endOfDocument)
        }
        titleLabel.text = entry.courseName
        pacerRow.isOn = (entry.withPacer as NSString?)?.boolValue ?? false
        stoppedRow.isOn = (entry.stoppedHere as NSString?)?.boolValue ?? false

        dateField.date = entry.entryTime ?? Date()

        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: entry.entryTime ?? Date())
        customPicker.hours = components.hour ?? 0
        customPicker.mins = components.minute ?? 0
        customPicker.secs = components.second ?? 0
        customPicker.selectRowsInPicker()
        timeField.text = String(format: "%02ld:%02ld:%02ld", components.hour ?? 0, components.minute ?? 0, components.second ?? 0)

        onBibNumberChanged(nil)
    }

    // MARK: - Helpers

    private func populateTimeAndFlags(_ entry: EntryModel) {
        entry.fullName = effort?.fullName
        entry.entryTime = dateField.date.addingTimeInterval(Double(customPicker.getTimeInMS() / 1000))
        entry.displayTime = timeField.text

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayString = formatter.string(from: dateField.date)
        let tzOffset = TimeZone.current.secondsFromGMT() / 60 / 60
        let sign = tzOffset < 0 ? "" : "+"
        entry.absoluteTime = String(format: "%@ %@\(sign)%02d:00", dayString, timeField.text ?? "", tzOffset)

        entry.withPacer = pacerRow.isOn ? "true" : "false"
        entry.stoppedHere = stoppedRow.isOn ? "true" : "false"
    }

    private func saveContext() {
        NSManagedObjectContext.mr_default().processPendingChanges()
        NSManagedObjectContext.mr_default().mr_saveOnlySelfAndWait()
    }
}

// MARK: - SwitchRow

/// Settings-style row: a title label on the left and a `UISwitch` on the right.
/// Mirrors the private `SheetRow` pattern in `BottomSheetPicker`.
private final class SwitchRow: UIView {

    var valueChanged: ((Bool) -> Void)?

    var isOn: Bool {
        get { toggle.isOn }
        set { toggle.setOn(newValue, animated: false) }
    }

    private let toggle: UISwitch = {
        let s = UISwitch()
        s.onTintColor = Theme.tint
        return s
    }()

    init(title: String) {
        super.init(frame: .zero)

        let label = UILabel()
        label.text = title
        label.font = Theme.Font.field
        label.textColor = Theme.label

        let row = UIStackView(arrangedSubviews: [label, toggle])
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        toggle.addTarget(self, action: #selector(switched), for: .valueChanged)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 52),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    @objc private func switched() {
        valueChanged?(toggle.isOn)
    }
}
