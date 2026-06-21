//
//  OSTRunnerTrackerViewController.swift
//  OST Tracker
//
//  The app's core bib-entry screen, rebuilt in the new design language. The view
//  hierarchy is now a single adaptive Auto Layout tree (root vertical UIStackView
//  pinned to the safe-area guide) built entirely in code — no XIB, no frame-math.
//  Styling is sourced from `Theme` (colors + Font roles); the entry/toggle buttons
//  mirror `PrimaryButton`. The embedded `NumberPadView` and `OSTRunnerBadge` are
//  reused as-is.
//
//  Behavior is preserved verbatim from the prior implementation: the entry-button
//  permutations (1-in / 1-out / 1-in+1-out / 2-in / 2-out) with their
//  leftBitKey/rightBitKey semantics, the bib lookup, the record flow, and the
//  edit-sheet present flow.
//
//  The bib field is watched via KVO on `text` because NumberPadView mutates the
//  text programmatically (a target/action editingChanged event would not fire).
//

import UIKit
import CoreData

@objc(OSTRunnerTrackerViewController)
class OSTRunnerTrackerViewController: OSTBaseViewController, UITextFieldDelegate {

    // MARK: - Programmatic views (formerly XIB outlets)

    @objc let txtBibNumber = UITextField()
    private let numberPad = NumberPadView()

    private let lblTitle = UILabel()
    private let lblTime = UILabel()
    private let lblTimeOfTheDay = UILabel()
    private let btnMenu = UIButton(type: .system)
    private let syncBadgeLabel = UILabel()

    private let btnLeft = UIButton(type: .custom)
    private let btnRight = UIButton(type: .custom)
    private let lblInTimeBadge = UILabel()
    private let lblOutTimeBadge = UILabel()

    private let btnStopped = UIButton(type: .custom)
    private let btnPacer = UIButton(type: .custom)

    private let lblPersonAdded = UILabel()
    private let lblRunnerInfo = UILabel()
    private let lblSecondaryInfo = UILabel()
    private let lblAdded = UILabel()
    private let runnerBadge = OSTRunnerBadge(frame: CGRect(x: 0, y: 0, width: 320, height: 120))

    // Toggle row: a horizontal stack so the pacer toggle can be hidden cleanly.
    private let toggleRow = UIStackView()
    // Entry buttons live in a horizontal stack; permutations hide a button instead
    // of doing width math.
    private let entryRow = UIStackView()
    // Display zone + number-pad split. In landscape we flip this axis to side-by-side.
    private let bodyStack = UIStackView()

    private var entryButtonHeight: NSLayoutConstraint?

    // MARK: - State

    private var timer: Timer?
    private var dayString = ""
    private var racer: EffortModel?
    private var entryDateTime: Date?
    private var lastEntry: EntryModel?
    private var leftBitKey: String?
    private var rightBitKey: String?

    private static let didRegisterBibNotification = Notification.Name("OSTRunnerTrackerViewControllerDidRegisterBibNotification")

    // Hoisted so onTick (fires ~10×/s) doesn't allocate formatters each tick.
    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    // Weekday + 12-hour clock, matching the aid-station field view ("Fri 7:05AM").
    private static let dayClockFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE h:mma"; return f
    }()

    // MARK: - Auto Sync status strip

    private let statusStrip: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.isUserInteractionEnabled = true
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private var statusStripHeight: NSLayoutConstraint?
    private var didInsertStatusStrip = false

    private func color(for state: AutoSyncState) -> (UIColor, UIColor) {
        switch state {
        case .synced:  return (Theme.success, .white)
        case .pending: return (Theme.tint, .white)
        case .syncing: return (UIColor(red: 1, green: 0.85, blue: 0.30, alpha: 1), .black)
        case .failed:  return (Theme.destructive, .white)
        case .offline: return (Theme.secondaryLabel, .white)
        case .disabled: return (.clear, .clear)
        }
    }

    private func renderStatus(_ status: AutoSyncStatus) {
        installStatusStripIfNeeded()
        let visible = status.state != .disabled
        statusStrip.isHidden = !visible
        statusStripHeight?.constant = visible ? 28 : 0
        guard visible else { return }
        let (bg, fg) = color(for: status.state)
        statusStrip.backgroundColor = bg
        statusStrip.textColor = fg
        statusStrip.text = status.stripText
    }

    @objc private func onStatusChanged() { renderStatus(AutoSyncController.shared.currentStatus) }

    @objc private func onStripTapped() {
        guard AutoSyncController.shared.currentStatus.isTappableForRetry else { return }
        AutoSyncController.shared.forceRetry()
    }

    /// The status strip sits just below the header bar and pushes the body down via
    /// its own height constraint (no frame shifting).
    private func installStatusStripIfNeeded() {
        guard !didInsertStatusStrip else { return }
        didInsertStatusStrip = true
        statusStrip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onStripTapped)))
        rootStack.insertArrangedSubview(statusStrip, at: 1)
        let h = statusStrip.heightAnchor.constraint(equalToConstant: 0)
        h.isActive = true
        statusStripHeight = h
    }

    private let rootStack = UIStackView()

    // MARK: - Lifecycle

    override func loadView() {
        view = UIView()
        view.backgroundColor = Theme.background
        buildUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Embedded pad (not an inputView), so playInputClick() can't fire —
        // play the click directly so key taps are audible on the timing screen.
        numberPad.tapSound = .alwaysClick
        numberPad.attach(to: txtBibNumber)

        txtBibNumber.addObserver(self, forKeyPath: "text", options: [.new, .old], context: nil)
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(onStatusChanged),
                                               name: AutoSyncController.statusChangedNotification, object: nil)
        renderStatus(AutoSyncController.shared.currentStatus)
        AppDelegate.getInstance()?.rightMenuVC.closeDrawer()
        lblTitle.text = CurrentCourse.getCurrentCourse()?.splitName

        configureEntryButtons()
        configurePacerToggle()
        startClock()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: AutoSyncController.statusChangedNotification, object: nil)
        timer?.invalidate()
        timer = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ostPositionBadgeAtMenu()
        runnerBadge.adjustFontSizes()
    }

    /// Positions the sync badge as a corner badge poking out beyond the menu
    /// button's top-right, so it overlaps only the icon's corner — never the
    /// "Menu" text. Overrides the base VC's inside-the-corner placement.
    override func ostPositionBadgeAtMenu() {
        guard let badgeSuper = syncBadgeLabel.superview, let menuSuper = btnMenu.superview else { return }
        let corner = menuSuper.convert(CGPoint(x: btnMenu.frame.maxX, y: btnMenu.frame.minY), to: badgeSuper)
        var f = syncBadgeLabel.frame
        f.origin.x = (corner.x - f.width * 0.6).rounded()
        f.origin.y = (corner.y - f.height * 0.35).rounded()
        syncBadgeLabel.frame = f
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyAdaptiveSizing()
    }

    // MARK: - UI construction

    private func buildUI() {
        rootStack.axis = .vertical
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        rootStack.addArrangedSubview(makeHeader())
        rootStack.addArrangedSubview(makeBody())

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: guide.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.backgroundColor = Theme.secondaryBackground

        lblTitle.font = Theme.Font.button
        lblTitle.textColor = Theme.label
        lblTitle.translatesAutoresizingMaskIntoConstraints = false

        // Hamburger on the right so the sync badge (anchored top-right by the base
        // VC's ostPositionBadgeAtMenu) sits over the icon, not the word.
        btnMenu.setTitle("Menu ☰", for: .normal)
        btnMenu.setTitleColor(Theme.tint, for: .normal)
        btnMenu.titleLabel?.font = Theme.Font.button
        btnMenu.addTarget(self, action: #selector(onRight(_:)), for: .touchUpInside)
        btnMenu.translatesAutoresizingMaskIntoConstraints = false

        // Sync-count badge, overlaid on the menu button (base VC drives its text via
        // `menuButton`/`badgeLabel` + `updateSyncBadge` / `ostPositionBadgeAtMenu`).
        syncBadgeLabel.backgroundColor = Theme.destructive
        syncBadgeLabel.textColor = .white
        syncBadgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        syncBadgeLabel.textAlignment = .center
        syncBadgeLabel.clipsToBounds = true
        syncBadgeLabel.isHidden = true
        syncBadgeLabel.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        syncBadgeLabel.layer.cornerRadius = 10
        // Thin ring in the header color so the badge reads as a floating corner
        // badge over the menu icon, not a blob sitting on it.
        syncBadgeLabel.layer.borderWidth = 2
        syncBadgeLabel.layer.borderColor = Theme.secondaryBackground.cgColor

        let headerStack = UIStackView(arrangedSubviews: [lblTitle, UIView(), btnMenu])
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerStack)
        header.addSubview(syncBadgeLabel)

        // Wire the base-VC sync-badge machinery to our programmatic views.
        menuButton = btnMenu
        badgeLabel = syncBadgeLabel

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 56),
            headerStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    private func makeBody() -> UIView {
        bodyStack.axis = .vertical
        bodyStack.spacing = 0

        bodyStack.addArrangedSubview(makeDisplayZone())
        bodyStack.addArrangedSubview(makeNumberPadContainer())
        return bodyStack
    }

    private func makeDisplayZone() -> UIView {
        let zone = UIView()
        zone.backgroundColor = Theme.background

        // Clock + time-of-day
        lblTime.font = Theme.Font.clock
        lblTime.textColor = Theme.label
        lblTime.textAlignment = .center

        lblTimeOfTheDay.font = Theme.Font.caption
        lblTimeOfTheDay.textColor = Theme.secondaryLabel
        lblTimeOfTheDay.textAlignment = .center

        // Bib field
        txtBibNumber.font = Theme.Font.bib
        txtBibNumber.textColor = Theme.label
        txtBibNumber.textAlignment = .center
        txtBibNumber.tintColor = .clear // hide the caret — the embedded number pad drives input
        txtBibNumber.keyboardType = .numberPad
        txtBibNumber.delegate = self
        txtBibNumber.placeholder = ""
        txtBibNumber.adjustsFontSizeToFitWidth = true
        txtBibNumber.minimumFontSize = 28
        // The embedded pad drives input; suppress the system keyboard.
        txtBibNumber.inputView = UIView()

        // Runner result line
        lblPersonAdded.font = Theme.Font.runnerName
        lblPersonAdded.textColor = Theme.label
        lblPersonAdded.textAlignment = .center
        lblPersonAdded.numberOfLines = 1
        lblPersonAdded.adjustsFontSizeToFitWidth = true
        lblPersonAdded.minimumScaleFactor = 0.6
        lblPersonAdded.text = "Enter Bib Number"

        lblRunnerInfo.font = Theme.Font.button
        lblRunnerInfo.textColor = Theme.secondaryLabel
        lblRunnerInfo.textAlignment = .center

        lblSecondaryInfo.font = Theme.Font.field
        lblSecondaryInfo.textColor = Theme.secondaryLabel
        lblSecondaryInfo.textAlignment = .center
        lblSecondaryInfo.numberOfLines = 0

        lblAdded.font = Theme.Font.field
        lblAdded.textColor = Theme.secondaryLabel
        lblAdded.textAlignment = .center
        lblAdded.isHidden = true

        runnerBadge.isHidden = true
        runnerBadge.isUserInteractionEnabled = true
        runnerBadge.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onRunnerInfo(_:))))

        // Constant-height result slot so recording an entry swaps detail-lines →
        // badge WITHOUT changing height: the toggle/entry buttons below never shift.
        let resultSlot = makeResultSlot()

        let displayStack = UIStackView(arrangedSubviews: [
            lblTime, lblTimeOfTheDay, txtBibNumber,
            lblPersonAdded, resultSlot,
            makeToggleRow(), makeEntryRow(),
        ])
        displayStack.axis = .vertical
        displayStack.alignment = .fill
        displayStack.spacing = 8
        displayStack.translatesAutoresizingMaskIntoConstraints = false
        displayStack.setCustomSpacing(2, after: lblTime)
        displayStack.setCustomSpacing(14, after: txtBibNumber)
        displayStack.setCustomSpacing(16, after: toggleRow) // separate flags from the In/Out actions
        zone.addSubview(displayStack)

        NSLayoutConstraint.activate([
            displayStack.topAnchor.constraint(equalTo: zone.topAnchor, constant: 8),
            displayStack.leadingAnchor.constraint(equalTo: zone.leadingAnchor, constant: 16),
            displayStack.trailingAnchor.constraint(equalTo: zone.trailingAnchor, constant: -16),
            displayStack.bottomAnchor.constraint(lessThanOrEqualTo: zone.bottomAnchor, constant: -8),
        ])
        return zone
    }

    /// The constant-height area below the runner name. The bib-lookup detail lines
    /// (runner info / secondary / location) and the recorded-runner badge are
    /// overlaid in the same slot and pinned to it; the action methods toggle which
    /// one is shown. Because the slot height is fixed, showing the badge never
    /// reflows the layout — the toggle and entry buttons stay put.
    private func makeResultSlot() -> UIView {
        let slot = UIView()
        slot.translatesAutoresizingMaskIntoConstraints = false

        let secondaryStack = UIStackView(arrangedSubviews: [lblRunnerInfo, lblSecondaryInfo, lblAdded])
        secondaryStack.axis = .vertical
        secondaryStack.alignment = .fill
        secondaryStack.spacing = 2
        secondaryStack.translatesAutoresizingMaskIntoConstraints = false
        slot.addSubview(secondaryStack)

        runnerBadge.translatesAutoresizingMaskIntoConstraints = false
        slot.addSubview(runnerBadge)

        NSLayoutConstraint.activate([
            slot.heightAnchor.constraint(equalToConstant: 120),

            secondaryStack.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
            secondaryStack.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
            secondaryStack.centerYAnchor.constraint(equalTo: slot.centerYAnchor),

            runnerBadge.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
            runnerBadge.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
            runnerBadge.topAnchor.constraint(equalTo: slot.topAnchor),
            runnerBadge.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
        ])
        return slot
    }

    private func makeToggleRow() -> UIView {
        styleToggle(btnStopped, title: "Dropping")
        styleToggle(btnPacer, title: "With pacer")
        btnStopped.addTarget(self, action: #selector(onBtnStopped(_:)), for: .touchUpInside)
        btnPacer.addTarget(self, action: #selector(onButtonPacer(_:)), for: .touchUpInside)

        toggleRow.axis = .horizontal
        toggleRow.distribution = .fillEqually
        toggleRow.spacing = 10
        toggleRow.addArrangedSubview(btnStopped)
        toggleRow.addArrangedSubview(btnPacer)
        return toggleRow
    }

    private func styleToggle(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = Theme.Font.field
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.setTitleColor(Theme.label, for: .normal)
        button.layer.cornerRadius = Theme.Metric.cornerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.separator.cgColor
        // Leading checkbox makes these read as on/off flags, distinct from the
        // solid In/Out action buttons directly below.
        button.setImage(Self.checkboxImage(on: false), for: .normal)
        button.setImage(Self.checkboxImage(on: true), for: .selected)
        button.imageView?.contentMode = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 18)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        refreshToggleStyle(button)
        button.heightAnchor.constraint(equalToConstant: 46).isActive = true
    }

    /// Neutral pill when off; a subtle tint wash when on — never the solid fill of
    /// the entry buttons, so it stays legible as a checkbox rather than an action.
    private func refreshToggleStyle(_ button: UIButton) {
        button.backgroundColor = button.isSelected
            ? Theme.tint.withAlphaComponent(0.14)
            : Theme.secondaryBackground
    }

    /// Checkbox glyph: rounded outline when off, filled tint with a white check when
    /// on. (Baked image — colors don't re-resolve on a light/dark switch, matching
    /// the file's other cgColor uses.)
    private static func checkboxImage(on: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { _ in
            let box = UIBezierPath(roundedRect: CGRect(x: 1.5, y: 1.5, width: 21, height: 21), cornerRadius: 6)
            if on {
                Theme.tint.setFill(); box.fill()
                let check = UIBezierPath()
                check.move(to: CGPoint(x: 6.5, y: 12.5))
                check.addLine(to: CGPoint(x: 10.5, y: 16.5))
                check.addLine(to: CGPoint(x: 17.5, y: 7.5))
                check.lineWidth = 2.4
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                UIColor.white.setStroke(); check.stroke()
            } else {
                box.lineWidth = 1.8
                Theme.secondaryLabel.setStroke(); box.stroke()
            }
        }.withRenderingMode(.alwaysOriginal)
    }

    private func makeEntryRow() -> UIView {
        styleEntryButton(btnLeft, tag: 1, badge: lblInTimeBadge)
        styleEntryButton(btnRight, tag: 2, badge: lblOutTimeBadge)

        entryRow.axis = .horizontal
        entryRow.distribution = .fillEqually
        entryRow.spacing = 8
        entryRow.addArrangedSubview(btnLeft)
        entryRow.addArrangedSubview(btnRight)

        let h = btnLeft.heightAnchor.constraint(equalToConstant: Theme.Metric.buttonHeight + 16)
        h.isActive = true
        entryButtonHeight = h
        btnRight.heightAnchor.constraint(equalTo: btnLeft.heightAnchor).isActive = true
        return entryRow
    }

    private func styleEntryButton(_ button: UIButton, tag: Int, badge: UILabel) {
        button.tag = tag
        button.titleLabel?.font = Theme.Font.button
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.numberOfLines = 2
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = Theme.tint
        button.layer.cornerRadius = Theme.Metric.cornerRadius
        button.addTarget(self, action: #selector(onEntryButton(_:)), for: .touchUpInside)

        // Count badge overlaid in the top-right corner.
        badge.font = Theme.Font.caption
        badge.textColor = .white
        badge.backgroundColor = Theme.destructive
        badge.textAlignment = .center
        badge.clipsToBounds = true
        badge.layer.cornerRadius = 11
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22),
            badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
        ])
    }

    private func makeNumberPadContainer() -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.background
        numberPad.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numberPad)
        NSLayoutConstraint.activate([
            numberPad.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            numberPad.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            numberPad.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            numberPad.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    // MARK: - Entry-button permutations

    /// Reproduces the data-driven setup from the old `viewWillAppear`: read
    /// `splitAttributes["entries"]`, filter `subSplitKind` in/out, then set button
    /// titles, visibility, and leftBitKey/rightBitKey identically. Layout is driven
    /// by hiding a button in the horizontal stack (no width math).
    private func configureEntryButtons() {
        btnLeft.isHidden = false
        btnRight.isHidden = false
        leftBitKey = nil
        rightBitKey = nil

        let entries = (CurrentCourse.getCurrentCourse()?.splitAttributes as? [String: Any])?["entries"] as? [[String: Any]] ?? []
        let splitEntriesIn = entries.filter { ($0["subSplitKind"] as? String) == "in" }
        let splitEntriesOut = entries.filter { ($0["subSplitKind"] as? String) == "out" }

        if splitEntriesIn.count == 1 && splitEntriesOut.count == 0 {
            btnRight.isHidden = true
            btnLeft.setTitle(splitEntriesIn[0]["label"] as? String, for: .normal)
            leftBitKey = "in"
        }
        if splitEntriesIn.count == 0 && splitEntriesOut.count == 1 {
            btnLeft.isHidden = true
            rightBitKey = "out"
            btnRight.setTitle(splitEntriesOut[0]["label"] as? String, for: .normal)
        } else if splitEntriesIn.count == 1 && splitEntriesOut.count == 1 {
            btnRight.isHidden = false
            btnLeft.isHidden = false
            btnLeft.setTitle(splitEntriesIn[0]["label"] as? String, for: .normal)
            btnRight.setTitle(splitEntriesOut[0]["label"] as? String, for: .normal)
            leftBitKey = "in"
            rightBitKey = "out"
        } else if splitEntriesIn.count == 2 {
            btnRight.isHidden = false
            btnLeft.isHidden = false
            btnLeft.setTitle(splitEntriesIn[0]["label"] as? String, for: .normal)
            btnRight.setTitle(splitEntriesIn[1]["label"] as? String, for: .normal)
            leftBitKey = "in"
            rightBitKey = "in"
        } else if splitEntriesOut.count == 2 {
            btnRight.isHidden = false
            btnLeft.isHidden = false
            btnLeft.setTitle(splitEntriesOut[0]["label"] as? String, for: .normal)
            btnRight.setTitle(splitEntriesOut[1]["label"] as? String, for: .normal)
            leftBitKey = "out"
            rightBitKey = "out"
        }
    }

    private func configurePacerToggle() {
        let monitors = CurrentCourse.getCurrentCourse()?.monitorPacers?.boolValue == true
        btnPacer.isHidden = !monitors
    }

    // MARK: - Adaptivity

    /// Scale clock/bib/runner-name fonts and the entry-button height up on iPad, and
    /// flip the display-zone↔number-pad arrangement side-by-side in landscape. No
    /// frame-math — only font sizes and the body stack axis change.
    private func applyAdaptiveSizing() {
        let isPad = traitCollection.userInterfaceIdiom == .pad

        lblTime.font = isPad ? Theme.Font.resized(Theme.Font.clock, to: 52) : Theme.Font.clock
        txtBibNumber.font = isPad ? Theme.Font.resized(Theme.Font.bib, to: 96) : Theme.Font.bib
        lblPersonAdded.font = isPad ? Theme.Font.resized(Theme.Font.runnerName, to: 34) : Theme.Font.runnerName
        entryButtonHeight?.constant = isPad ? 110 : Theme.Metric.buttonHeight + 16

        let landscape = view.bounds.width > view.bounds.height
        let desiredAxis: NSLayoutConstraint.Axis = landscape ? .horizontal : .vertical
        if bodyStack.axis != desiredAxis {
            bodyStack.axis = desiredAxis
            bodyStack.distribution = landscape ? .fillEqually : .fill
        }
    }

    /// Runs only while the screen is visible (started in viewWillAppear, invalidated
    /// in viewWillDisappear). Block-based with [weak self] so it never retains the VC.
    private func startClock() {
        timer?.invalidate()
        onTick() // populate immediately so the clock doesn't flash empty on appear
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.onTick()
        }
    }

    private func onTick() {
        let date = Date()
        lblTime.text = Self.clockFormatter.string(from: date)
        lblTimeOfTheDay.text = Self.dayClockFormatter.string(from: date)
        dayString = Self.dayKeyFormatter.string(from: date)
        entryDateTime = date
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
        refreshToggleStyle(btnPacer)
        refreshToggleStyle(btnStopped)
        txtBibNumber.text = nil
        lblInTimeBadge.isHidden = true
        lblOutTimeBadge.isHidden = true
    }

    @IBAction func onEntryButton(_ sender: Any) {
        txtBibNumber.removeObserver(self, forKeyPath: "text")
        UIDevice.current.playInputClick()

        if !BibEntry.isRecordable(txtBibNumber.text) {
            OSTSound.shared().play("ost-remote-bib-not-found")
            txtBibNumber.addObserver(self, forKeyPath: "text", options: [.new, .old], context: nil)
            return
        }

        lblOutTimeBadge.isHidden = true
        lblInTimeBadge.isHidden = true
        guard let course = CurrentCourse.getCurrentCourse(),
              let entry = EntryModel.mr_createEntity() as? EntryModel else { return }

        entry.bibNumber = txtBibNumber.text
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
        refreshToggleStyle(btnPacer)
        refreshToggleStyle(btnStopped)
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
            self.lblRunnerInfo.textColor = Theme.destructive
            self.txtBibNumber.textColor = Theme.destructive
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
        refreshToggleStyle(btnPacer)
        OSTSound.shared().play("ost-remote-switch-1")
    }

    @IBAction func onBtnStopped(_ sender: Any) {
        btnStopped.isSelected.toggle()
        refreshToggleStyle(btnStopped)
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
        lblRunnerInfo.textColor = Theme.secondaryLabel
        txtBibNumber.textColor = Theme.label

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
            lblRunnerInfo.textColor = Theme.destructive
            txtBibNumber.textColor = Theme.destructive
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
        txtBibNumber.removeObserver(self, forKeyPath: "text")
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
