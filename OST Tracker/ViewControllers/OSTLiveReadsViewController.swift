import UIKit

/// Read-only live monitor of raw times ("reads") at the device's current
/// station. Auto-polls every 5s while visible; pauses off-screen / backgrounded.
/// New reads are highlighted briefly. Header Refresh button + Go-to-Live-Entry.
final class OSTLiveReadsViewController: OSTBaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let pollInterval: TimeInterval = 5
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()
    private let updatedLabel = UILabel()
    private let liveDot = UIView()

    private var rows: [RawTime] = []
    private var highWaterMark = 0
    private var newIds: Set<Int> = []
    private var hasLoadedOnce = false
    private var nameByBib: [String: String] = [:]
    private var timer: Timer?

    private var groupId: String { CurrentCourse.getCurrentCourse()?.eventGroupId ?? "" }
    private var stationName: String { CurrentCourse.getCurrentCourse()?.splitName ?? "" }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(stopPolling),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startPolling),
            name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        titleLabel.text = "Live Reads — \(stationName)"
        rows = []; highWaterMark = 0; newIds = []; hasLoadedOnce = false
        loadRoster()
        tableView.reloadData()
        guard !groupId.isEmpty, !stationName.isEmpty else { updatedLabel.text = "No station selected"; return }
        fetch(showSpinner: true)
        startPolling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPolling()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Polling

    @objc private func startPolling() {
        stopPolling()
        guard view.window != nil, !groupId.isEmpty else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetch(showSpinner: false)
        }
    }

    @objc private func stopPolling() { timer?.invalidate(); timer = nil }

    @objc private func onRefresh() { fetch(showSpinner: false); startPolling() }

    @objc private func onGoToLiveEntry() { AppDelegate.getInstance()?.showTracker() }

    /// Builds a bib → runner-name map from the locally-cached roster so reads can
    /// be labeled with names. Same source the live tracker uses to resolve a bib.
    private func loadRoster() {
        let efforts = EffortModel.mr_findAll(with: nil) as? [EffortModel] ?? []
        var map: [String: String] = [:]
        for e in efforts {
            guard let bib = e.bibNumber?.stringValue, let name = e.fullName, !name.isEmpty else { continue }
            map[bib] = name
        }
        nameByBib = map
    }

    @objc private func onMenu() {
        AppDelegate.getInstance()?.rightMenuVC.toggleRightSideMenuCompletion(nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostPositionBadgeAtMenu()
    }

    private func fetch(showSpinner: Bool) {
        guard !groupId.isEmpty, !stationName.isEmpty else { return }
        if showSpinner { ostShowBlockingSpinner() }
        OSTBackend.shared.fetchRawTimes(groupId: groupId, splitName: stationName) { [weak self] object, error in
            guard let self = self else { return }
            if showSpinner { self.ostHideBlockingSpinner() }
            guard error == nil, let dict = object as? [String: Any] else {
                self.liveDot.backgroundColor = Theme.secondaryLabel
                self.updatedLabel.text = "Couldn't refresh"
                return
            }
            let incoming = RawTime.parse(dict)
            let result = LiveReadsMerge.merge(existing: self.rows, incoming: incoming, highWaterMark: self.highWaterMark)
            self.rows = result.rows
            self.highWaterMark = result.highWaterMark
            // Flash only genuinely-new reads; suppress the first fill, where the
            // empty→full diff would mark every row as "new". Cleared per-row in
            // willDisplay so each id flashes exactly once.
            if self.hasLoadedOnce { self.newIds.formUnion(result.newIds) }
            self.hasLoadedOnce = true
            self.liveDot.backgroundColor = Theme.success
            self.updatedLabel.text = "Updated " + Self.clock.string(from: Date())
            self.tableView.reloadData()
        }
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "read") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "read")
        let r = rows[indexPath.row]
        let kind = (r.subSplitKind ?? "").uppercased()
        let time = LiveReadsFormat.clock(enteredTime: r.enteredTime, absoluteTime: r.absoluteTime)
        cell.textLabel?.text = LiveReadsFormat.nameLine(bib: r.bib, name: nameByBib[r.bib])
        cell.textLabel?.textColor = Theme.label
        var flags: [String] = []
        if let lap = r.lap, lap > 1 { flags.append("L\(lap)") }
        if r.withPacer { flags.append("pacer") }
        if r.stoppedHere { flags.append("stopped") }
        let source = LiveReadsFormat.friendlySource(r.source, myUUID: OSTSessionManager.getUUIDString())
        let meta = [time, kind.isEmpty ? "" : "[\(kind)]", source, flags.joined(separator: " · ")]
        cell.detailTextLabel?.text = meta.filter { !$0.isEmpty }.joined(separator: "   ")
        cell.detailTextLabel?.textColor = Theme.secondaryLabel
        cell.contentView.backgroundColor = .clear // highlight is applied in willDisplay
        return cell
    }

    /// Flash newly-arrived reads once, when the cell actually becomes visible
    /// (starting the animation from `cellForRowAt` is unreliable). Removing the
    /// id from `newIds` here means a row never re-flashes on scroll/reuse.
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row < rows.count, newIds.remove(rows[indexPath.row].id) != nil else { return }
        cell.contentView.backgroundColor = Theme.tint.withAlphaComponent(0.25)
        UIView.animate(withDuration: 1.2, delay: 0.4, options: [.allowUserInteraction]) {
            cell.contentView.backgroundColor = .clear
        }
    }

    // MARK: - UI construction

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    private func buildUI() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = Theme.secondaryBackground

        titleLabel.font = Theme.Font.button
        titleLabel.textColor = Theme.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        liveDot.layer.cornerRadius = 5
        liveDot.backgroundColor = Theme.secondaryLabel
        liveDot.translatesAutoresizingMaskIntoConstraints = false

        updatedLabel.font = Theme.Font.caption
        updatedLabel.textColor = Theme.secondaryLabel
        updatedLabel.translatesAutoresizingMaskIntoConstraints = false

        let refresh = UIButton(type: .system)
        refresh.setTitle("⟳", for: .normal)
        refresh.setTitleColor(Theme.tint, for: .normal)
        refresh.titleLabel?.font = .systemFont(ofSize: 26, weight: .semibold)
        refresh.accessibilityLabel = "Refresh"
        refresh.addTarget(self, action: #selector(onRefresh), for: .touchUpInside)

        let menuBtn = UIButton(type: .system)
        menuBtn.configureAsMenuButton(target: self, action: #selector(onMenu))
        menuButton = menuBtn // base VC anchors the sync badge to this

        let goLive = PrimaryButton(title: "Go to Live Entry", role: .primary)
        goLive.translatesAutoresizingMaskIntoConstraints = false
        goLive.addTarget(self, action: #selector(onGoToLiveEntry), for: .touchUpInside)

        // Title + controls on top, live/updated status on its own line below —
        // they don't both fit on one row at phone width.
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, UIView(), refresh, menuBtn])
        titleRow.alignment = .center
        titleRow.spacing = 12

        let statusStack = UIStackView(arrangedSubviews: [liveDot, updatedLabel, UIView()])
        statusStack.alignment = .center
        statusStack.spacing = 6

        let headerStack = UIStackView(arrangedSubviews: [titleRow, statusStack])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.alignment = .fill
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = 56
        tableView.separatorColor = Theme.separator

        view.addSubview(header)
        view.addSubview(tableView)
        view.addSubview(goLive)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            liveDot.widthAnchor.constraint(equalToConstant: 10),
            liveDot.heightAnchor.constraint(equalToConstant: 10),

            header.topAnchor.constraint(equalTo: guide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 68),
            headerStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: goLive.topAnchor, constant: -8),

            goLive.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Theme.Metric.horizontalInset),
            goLive.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Theme.Metric.horizontalInset),
            goLive.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
        ])
    }
}
