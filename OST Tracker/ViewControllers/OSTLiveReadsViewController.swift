import UIKit

/// Read-only live monitor of raw times ("reads") at the device's current
/// station. Auto-polls every 5s while visible; pauses off-screen / backgrounded.
/// New reads are highlighted briefly. Header Refresh button + Go-to-Live-Entry.
final class OSTLiveReadsViewController: OSTBaseViewController, UITableViewDataSource {

    private let pollInterval: TimeInterval = 5
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let titleLabel = UILabel()
    private let updatedLabel = UILabel()
    private let liveDot = UIView()

    private var rows: [RawTime] = []
    private var highWaterMark = 0
    private var newIds: Set<Int> = []
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
        rows = []; highWaterMark = 0; newIds = []
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
            self.newIds = Set(result.newIds)
            self.liveDot.backgroundColor = Theme.success
            self.updatedLabel.text = "Updated " + Self.clock.string(from: Date())
            self.tableView.reloadData()
            self.newIds = []
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
        let time = r.enteredTime ?? Self.shortTime(from: r.absoluteTime) ?? "—"
        cell.textLabel?.text = "#\(r.bib)   \(time)" + (kind.isEmpty ? "" : "   [\(kind)]")
        cell.textLabel?.textColor = Theme.label
        var flags: [String] = []
        if let lap = r.lap, lap > 1 { flags.append("L\(lap)") }
        if r.withPacer { flags.append("pacer") }
        if r.stoppedHere { flags.append("stopped") }
        let source = r.source ?? ""
        cell.detailTextLabel?.text = [source, flags.joined(separator: " · ")].filter { !$0.isEmpty }.joined(separator: "   ")
        cell.detailTextLabel?.textColor = Theme.secondaryLabel
        cell.contentView.backgroundColor = newIds.contains(r.id) ? Theme.tint.withAlphaComponent(0.15) : .clear
        if newIds.contains(r.id) {
            UIView.animate(withDuration: 1.5) { cell.contentView.backgroundColor = .clear }
        }
        return cell
    }

    // MARK: - UI construction

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    private static func shortTime(from iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let inF = ISO8601DateFormatter()
        inF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = inF.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
        return clock.string(from: d)
    }

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
        refresh.setTitle("⟳ Refresh", for: .normal)
        refresh.setTitleColor(Theme.tint, for: .normal)
        refresh.titleLabel?.font = Theme.Font.button
        refresh.addTarget(self, action: #selector(onRefresh), for: .touchUpInside)

        let goLive = PrimaryButton(title: "Go to Live Entry", role: .primary)
        goLive.translatesAutoresizingMaskIntoConstraints = false
        goLive.addTarget(self, action: #selector(onGoToLiveEntry), for: .touchUpInside)

        let statusStack = UIStackView(arrangedSubviews: [liveDot, updatedLabel])
        statusStack.alignment = .center
        statusStack.spacing = 6

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), statusStack, refresh])
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)

        tableView.dataSource = self
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
            header.heightAnchor.constraint(equalToConstant: 56),
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
