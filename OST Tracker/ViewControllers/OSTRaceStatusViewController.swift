import UIKit

/// Read-only "race state" screen. Manual refresh. Two modes on one page:
/// By Runner (search an effort → their splits) and By Aid Station (pick a split →
/// the whole field). Event selector hides when the group has one event.
final class OSTRaceStatusViewController: OSTBaseViewController,
                                         UITableViewDataSource, UITableViewDelegate,
                                         UITextFieldDelegate {

    private enum Mode: Int { case runner = 0, station = 1 }

    private enum DisplayRow {
        case runnerMatch(EffortRow)
        case runnerStation(RunnerStationRow)
        case fieldRow(FieldRow)
        case message(String)
    }

    // State
    private var events: [EventRef] = []
    private var selectedEvent: EventRef?
    private var spread: EventSpread?
    private var mode: Mode = .runner
    private var selectedEffort: EffortRow?
    private var searchText = ""
    private var selectedSplitIndex: Int?
    private var rows: [DisplayRow] = []
    private var isFetchingSpread = false
    private var inFlightSlug: String?

    private var groupId: String { CurrentCourse.getCurrentCourse()?.eventGroupId ?? "" }

    // Views
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let eventList = SelectableOptionList(label: "Event")
    private let modeControl = UISegmentedControl(items: ["By Runner", "By Aid Station"])
    private let searchField = UITextField()
    private let stationButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    init() { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if spread == nil { loadEvents() }
    }

    // MARK: - Loading

    private func loadEvents() {
        guard !groupId.isEmpty else {
            infoLabel.text = "No event selected"
            return
        }
        ostShowBlockingSpinner()
        OSTBackend.shared.fetchEvents(inGroup: groupId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure:
                self.ostHideBlockingSpinner()
                self.ostPresentAlert(title: "Error", message: "Couldn't load events.")
            case .success(let refs):
                self.events = refs
                self.eventList.options = refs.map { $0.name }
                self.eventList.isHidden = refs.count <= 1
                let first = refs.first
                self.selectedEvent = first
                if let first = first { self.eventList.select(first.name) }
                if refs.isEmpty {
                    self.ostHideBlockingSpinner()
                    self.infoLabel.text = "No events available."
                    self.rows = [.message("No events available for this group.")]
                    self.tableView.reloadData()
                    return
                }
                self.loadSpread()
            }
        }
    }

    private func loadSpread() {
        guard let event = selectedEvent else { ostHideBlockingSpinner(); return }
        // Block a duplicate fetch for the SAME event, but let an event switch supersede an in-flight one.
        if isFetchingSpread, inFlightSlug == event.slug { return }
        isFetchingSpread = true
        inFlightSlug = event.slug
        ostShowBlockingSpinner()
        OSTBackend.shared.fetchSpread(eventSlug: event.slug) { [weak self] result in
            guard let self = self else { return }
            // Ignore a stale response for an event the user has since switched away from.
            guard event.slug == self.selectedEvent?.slug else { return }
            self.isFetchingSpread = false
            self.inFlightSlug = nil
            self.ostHideBlockingSpinner()
            switch result {
            case .failure:
                self.ostPresentAlert(title: "Error", message: "Couldn't load race data.")
            case .success(let spread):
                self.spread = spread
                self.selectedEffort = nil
                self.selectedSplitIndex = nil
                self.searchField.text = ""; self.searchText = ""
                self.reload()
            }
        }
    }

    // MARK: - Actions

    @objc private func onRefresh() { loadSpread() }

    @objc private func onMenu() {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostPositionBadgeAtMenu()
    }

    @objc private func onModeChanged() {
        mode = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .runner
        updateControlVisibility()
        reload()
    }

    @objc private func onStationTapped() {
        guard let spread = spread else { return }
        let titles = spread.splitHeaders.map { $0.title }
        let current = selectedSplitIndex.flatMap { titles.indices.contains($0) ? titles[$0] : nil }
        BottomSheetPicker.present(from: self, title: "Aid Station", options: titles,
                                  selected: current) { [weak self] choice in
            self?.selectedSplitIndex = titles.firstIndex(of: choice)
            self?.updateStationButtonTitle()
            self?.reload()
        }
    }

    @objc private func onSearchChanged() {
        searchText = searchField.text ?? ""
        if !searchText.isEmpty { selectedEffort = nil }
        reload()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }

    private func onEventChosen(_ name: String) {
        guard let ref = events.first(where: { $0.name == name }), ref.slug != selectedEvent?.slug else { return }
        selectedEvent = ref
        loadSpread()
    }

    // MARK: - Rendering

    private func updateControlVisibility() {
        searchField.isHidden = (mode != .runner)
        stationButton.isHidden = (mode != .station)
    }

    private func updateStationButtonTitle() {
        let name = selectedSplitIndex
            .flatMap { spread?.splitHeaders.indices.contains($0) == true ? spread?.splitHeaders[$0].title : nil }
        stationButton.setTitle("Aid Station: \(name ?? "Choose") ▾", for: .normal)
    }

    private func reload() {
        guard let spread = spread else { rows = [.message("Loading…")]; tableView.reloadData(); return }
        switch mode {
        case .runner:
            if let effort = selectedEffort, searchText.isEmpty {
                let progress = runnerProgress(effort, spread: spread)
                infoLabel.text = "\(progress.summary.name)  #\(progress.summary.bib)\n\(progress.summary.detail)"
                rows = progress.rows.map { .runnerStation($0) }
            } else {
                let matches = matchEfforts(searchText, in: spread.efforts)
                infoLabel.text = searchText.isEmpty ? "Type a bib or name to find a runner."
                                                    : "\(matches.count) match\(matches.count == 1 ? "" : "es")"
                rows = matches.isEmpty ? [.message(searchText.isEmpty ? "" : "No runners match.")]
                                       : matches.map { .runnerMatch($0) }
            }
        case .station:
            guard let idx = selectedSplitIndex, spread.splitHeaders.indices.contains(idx) else {
                infoLabel.text = "Pick an aid station."
                rows = [.message("Choose an aid station above.")]
                break
            }
            let field = stationField(splitIndex: idx, spread: spread)
            infoLabel.text = "\(spread.splitHeaders[idx].title) — \(field.countText)"
            rows = field.rows.map { .fieldRow($0) }
        }
        tableView.reloadData()
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "rs")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "rs")
        cell.backgroundColor = .clear
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.textColor = Theme.label
        cell.detailTextLabel?.textColor = Theme.secondaryLabel
        cell.accessoryType = .none
        cell.selectionStyle = .none

        switch rows[indexPath.row] {
        case .runnerMatch(let e):
            cell.textLabel?.text = "#\(e.bibNumber)  \(e.fullName)"
            cell.detailTextLabel?.text = e.flexibleGeolocation
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        case .runnerStation(let r):
            cell.textLabel?.text = r.title
            cell.detailTextLabel?.text = r.lines.map { line -> String in
                let prefix = line.label.map { "\($0)  " } ?? ""
                let tod = line.timeOfDay.isEmpty ? "" : "   \(line.timeOfDay)"
                return "\(prefix)\(line.elapsed)\(tod)"
            }.joined(separator: "\n")
        case .fieldRow(let f):
            let time = f.time.isEmpty ? "" : "   \(f.time)"
            cell.textLabel?.text = "#\(f.bib)  \(f.name)"
            cell.detailTextLabel?.text = "\(f.status)\(time)"
        case .message(let m):
            cell.textLabel?.text = m
            cell.detailTextLabel?.text = nil
            cell.textLabel?.textColor = Theme.secondaryLabel
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .runnerMatch(let e) = rows[indexPath.row] {
            selectedEffort = e
            searchField.text = ""; searchText = ""
            searchField.resignFirstResponder()
            reload()
        }
    }

    // MARK: - UI construction

    private func buildUI() {
        titleLabel.text = "Race Status"
        titleLabel.font = Theme.Font.title
        titleLabel.textColor = Theme.label

        let refresh = UIButton(type: .system)
        refresh.setTitle("⟳", for: .normal)
        refresh.setTitleColor(Theme.tint, for: .normal)
        refresh.titleLabel?.font = .systemFont(ofSize: 26, weight: .semibold)
        refresh.accessibilityLabel = "Refresh"
        refresh.addTarget(self, action: #selector(onRefresh), for: .touchUpInside)

        let menuBtn = UIButton(type: .system)
        menuBtn.setTitle("☰", for: .normal)
        menuBtn.setTitleColor(Theme.tint, for: .normal)
        menuBtn.titleLabel?.font = .systemFont(ofSize: 26)
        menuBtn.accessibilityLabel = "Menu"
        menuBtn.addTarget(self, action: #selector(onMenu), for: .touchUpInside)
        menuButton = menuBtn // base VC anchors the sync badge to this

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), refresh, menuBtn])
        titleRow.alignment = .center
        titleRow.spacing = 16

        eventList.onSelect = { [weak self] name in self?.onEventChosen(name) }
        eventList.isHidden = true

        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(onModeChanged), for: .valueChanged)

        searchField.placeholder = "Bib or name"
        searchField.borderStyle = .roundedRect
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.clearButtonMode = .whileEditing
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(onSearchChanged), for: .editingChanged)
        searchField.font = Theme.Font.field

        stationButton.setTitleColor(Theme.tint, for: .normal)
        stationButton.titleLabel?.font = Theme.Font.field
        stationButton.contentHorizontalAlignment = .left
        stationButton.addTarget(self, action: #selector(onStationTapped), for: .touchUpInside)
        stationButton.isHidden = true
        updateStationButtonTitle()

        infoLabel.font = Theme.Font.caption
        infoLabel.textColor = Theme.secondaryLabel
        infoLabel.numberOfLines = 0

        let controls = UIStackView(arrangedSubviews: [titleRow, eventList, modeControl,
                                                       searchField, stationButton, infoLabel])
        controls.axis = .vertical
        controls.spacing = 12
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.separatorColor = Theme.separator
        tableView.backgroundColor = .clear
        view.addSubview(tableView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            controls.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Theme.Metric.horizontalInset),
            controls.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Theme.Metric.horizontalInset),

            tableView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updateControlVisibility()
    }
}
