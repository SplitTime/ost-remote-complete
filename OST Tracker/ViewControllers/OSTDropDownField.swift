//
//  OSTDropDownField.swift
//  OST Tracker
//
//  Native replacement for the IQDropDownTextField pod: a UITextField whose input
//  view is a UIPickerView (list mode) or UIDatePicker (date mode). Reproduces the
//  small slice of IQDropDownTextField's API the app actually used —
//  `itemList`, `selectedItem`, `selectedRow`, `isOptionalDropDown`, `dropDownMode`,
//  `date`. Resolves in the XIBs by its @objc name (customClass="OSTDropDownField").
//

import UIKit

@objc enum OSTDropDownMode: Int {
    case list
    case datePicker
}

@objc(OSTDropDownField)
class OSTDropDownField: UITextField, UIPickerViewDataSource, UIPickerViewDelegate {

    /// When true the picker has a leading "Select" (no-selection) row.
    @objc var isOptionalDropDown: Bool = true {
        didSet { listPicker.reloadAllComponents() }
    }

    @objc var itemList: [String] = [] {
        didSet {
            listPicker.reloadAllComponents()
            syncTextToSelection()
        }
    }

    @objc var dropDownMode: OSTDropDownMode = .list {
        didSet { configureInputView() }
    }

    private let optionalTitle = "Select"

    private lazy var listPicker: UIPickerView = {
        let picker = UIPickerView()
        picker.dataSource = self
        picker.delegate = self
        return picker
    }()

    private lazy var datePickerView: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        return picker
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    override init(frame: CGRect) { super.init(frame: frame); configureInputView() }
    required init?(coder: NSCoder) { super.init(coder: coder); configureInputView() }

    private func configureInputView() {
        inputView = (dropDownMode == .datePicker) ? datePickerView : listPicker
    }

    // MARK: - Date mode

    @objc var date: Date {
        get { datePickerView.date }
        set { datePickerView.date = newValue; text = dateFormatter.string(from: newValue) }
    }

    @objc private func dateChanged() {
        text = dateFormatter.string(from: datePickerView.date)
    }

    // MARK: - List mode

    /// 0-based index into `itemList` (independent of the optional "Select" row).
    @objc var selectedRow: Int {
        get {
            let row = listPicker.selectedRow(inComponent: 0)
            return isOptionalDropDown ? row - 1 : row
        }
        set {
            let pickerRow = isOptionalDropDown ? newValue + 1 : newValue
            guard pickerRow >= 0, pickerRow < listPicker.numberOfRows(inComponent: 0) else { return }
            listPicker.selectRow(pickerRow, inComponent: 0, animated: false)
            syncTextToSelection()
        }
    }

    @objc var selectedItem: String? {
        get {
            let row = selectedRow
            return (row >= 0 && row < itemList.count) ? itemList[row] : nil
        }
        set {
            guard let value = newValue, let index = itemList.firstIndex(of: value) else { return }
            selectedRow = index
        }
    }

    private func syncTextToSelection() {
        guard dropDownMode == .list else { return }
        text = selectedItem
    }

    // MARK: - UIPickerView

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        itemList.count + (isOptionalDropDown ? 1 : 0)
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if isOptionalDropDown {
            return row == 0 ? optionalTitle : itemList[row - 1]
        }
        return itemList[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        syncTextToSelection()
    }
}
