//  CrossCheckGroupViewController.swift
//  OST Tracker
//
//  A drill-in list of bibs for one Cross Check status group (Recorded / Dropped
//  here / Not expected). Reuses the expected cell style; tapping a row opens the
//  per-bib action sheet.

import UIKit

final class CrossCheckGroupViewController: OSTBaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let groupTitle: String
    private var rows: [CrossCheckRow]
    private let onSetExpected: (CrossCheckRow, Bool) -> Void
    private let onReviewEntries: () -> Void

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(title: String, rows: [CrossCheckRow],
         onSetExpected: @escaping (CrossCheckRow, Bool) -> Void,
         onReviewEntries: @escaping () -> Void) {
        self.groupTitle = title
        self.rows = rows
        self.onSetExpected = onSetExpected
        self.onReviewEntries = onReviewEntries
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background

        titleLabel.text = "\(groupTitle) · \(rows.count)"
        titleLabel.font = Theme.Font.brand
        titleLabel.textColor = Theme.label

        closeButton.setTitle("Done", for: .normal)
        closeButton.setTitleColor(Theme.tint, for: .normal)
        closeButton.titleLabel?.font = Theme.Font.button
        closeButton.addTarget(self, action: #selector(onClose), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), closeButton])
        header.axis = .horizontal
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.background
        tableView.separatorColor = Theme.separator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(CrossCheckExpectedCell.self, forCellReuseIdentifier: CrossCheckExpectedCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(tableView)
        let guide = view.safeAreaLayoutGuide
        let inset = Theme.Metric.horizontalInset
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            header.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    @objc private func onClose() { dismiss(animated: true) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CrossCheckExpectedCell.reuseID, for: indexPath) as! CrossCheckExpectedCell
        cell.configure(with: rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        CrossCheckActionSheet.present(from: self,
                                      config: CrossCheckPresentation.sheetConfig(for: row),
                                      onSetExpected: { [weak self] expected in self?.onSetExpected(row, expected) },
                                      onReviewEntries: { [weak self] in self?.onReviewEntries() })
    }
}
