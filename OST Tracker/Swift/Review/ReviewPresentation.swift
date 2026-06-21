//  ReviewPresentation.swift
//  OST Tracker
//
//  Pure presentation logic for the Review/Sync list — no UIKit, no CoreData —
//  so the mapping/styling/title rules are unit-testable in isolation. Views and
//  the view controller consume these values.

import Foundation

/// Display values for one review row, derived from an entry's raw column strings.
struct ReviewEntryDisplay: Equatable {
    let time: String
    let name: String        // resolved; "Bib not found" when the bib has no name
    let bib: String?        // "#142", or nil for the "-1" placeholder / missing bib
    let inOut: String       // capitalized bitKey, e.g. "In" / "Out"
    let isSynced: Bool
    let isBibMissing: Bool
    let showsPacer: Bool
    let showsStopped: Bool

    /// Truthiness of the pacer/stopped flags follows `NSString.boolValue`
    /// (so "1" / "true" → true), matching the legacy CoreData string columns.
    init(displayTime: String?, fullName: String?, bibNumber: String?, bitKey: String?,
         submitted: Bool, withPacer: String?, stoppedHere: String?) {
        self.time = displayTime ?? ""
        let resolvedName = (fullName?.isEmpty ?? true) ? "Bib not found" : fullName!
        self.name = resolvedName
        self.isBibMissing = (resolvedName == "Bib not found")
        if let bibNumber = bibNumber, !bibNumber.isEmpty, bibNumber != "-1" {
            self.bib = "#\(bibNumber)"
        } else {
            self.bib = nil // missing / empty / "-1" placeholder → no bib chip (not a lone "#")
        }
        self.inOut = (bitKey ?? "").capitalized
        self.isSynced = submitted
        self.showsPacer = (withPacer as NSString?)?.boolValue ?? false
        self.showsStopped = (stoppedHere as NSString?)?.boolValue ?? false
    }
}

/// Semantic color role for a label — mapped to a `Theme` color by the view.
enum ReviewLabelRole { case normal, secondary, success, destructive }

/// The per-label styling for a row, as a pure function of its display values.
struct ReviewEntryStyle: Equatable {
    let timeRole: ReviewLabelRole
    let nameRole: ReviewLabelRole
    let bibRole: ReviewLabelRole
    let inOutRole: ReviewLabelRole
    let nameBold: Bool

    init(_ d: ReviewEntryDisplay) {
        if d.isSynced {
            timeRole = .success; nameRole = .success; bibRole = .success; inOutRole = .success
            nameBold = d.isBibMissing
        } else {
            timeRole = .normal; bibRole = .secondary; inOutRole = .secondary
            if d.isBibMissing {
                nameRole = .destructive; nameBold = true
            } else {
                nameRole = .normal; nameBold = false
            }
        }
    }
}

/// Bottom Sync button title + enabled state as a pure function of the unsynced
/// count and whether a sync is in flight.
enum ReviewSyncButton {
    static func title(unsyncedCount: Int) -> String {
        guard unsyncedCount > 0 else { return "All Synced" }
        return "Sync \(unsyncedCount) \(unsyncedCount == 1 ? "Time" : "Times")"
    }
    static func isEnabled(unsyncedCount: Int, isSyncing: Bool) -> Bool {
        unsyncedCount > 0 && !isSyncing
    }
}
