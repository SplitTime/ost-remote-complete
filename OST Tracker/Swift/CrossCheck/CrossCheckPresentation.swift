//  CrossCheckPresentation.swift
//  OST Tracker
//
//  Pure presentation logic for the Cross Check board — no UIKit, no CoreData —
//  so status bucketing and sheet rules are unit-testable in isolation. The view
//  controller adapts EffortModel into EffortFacts and renders the result.

import Foundation

enum CrossCheckStatus { case expected, recorded, droppedHere, notExpected }

/// Plain facts about one effort at the current split, derived by the VC from
/// EffortModel (so CoreData never crosses into this pure layer).
struct EffortFacts {
    let bib: String
    let name: String
    let hasEntries: Bool
    let isStopped: Bool
    let isExpected: Bool   // expected(withSplitName:) was nil or true
    let time: String?
}

struct CrossCheckRow: Equatable {
    let bib: String
    let name: String
    let status: CrossCheckStatus
    let time: String?
}

struct CrossCheckBoard: Equatable {
    let expected: [CrossCheckRow]
    let recorded: [CrossCheckRow]
    let droppedHere: [CrossCheckRow]
    let notExpected: [CrossCheckRow]

    var expectedCount: Int { expected.count }
    var recordedCount: Int { recorded.count }
    var droppedHereCount: Int { droppedHere.count }
    var notExpectedCount: Int { notExpected.count }
}

struct CrossCheckSheetConfig: Equatable {
    let bib: String
    let name: String
    let showsExpectedToggle: Bool
    let isExpected: Bool
}

enum CrossCheckPresentation {

    static func status(for facts: EffortFacts) -> CrossCheckStatus {
        if facts.hasEntries {
            return facts.isStopped ? .droppedHere : .recorded
        }
        return facts.isExpected ? .expected : .notExpected
    }

    /// Buckets efforts by status. Empty bibs are dropped (roster efforts always
    /// have a bib; this just guards a nil bibNumber that stringified to "").
    /// (The legacy effort-side "-1" filter was removed upstream in e0feae1 as
    /// obsolete — roster efforts never carry the "-1" entry placeholder.)
    static func build(from facts: [EffortFacts]) -> CrossCheckBoard {
        var expected: [CrossCheckRow] = []
        var recorded: [CrossCheckRow] = []
        var dropped: [CrossCheckRow] = []
        var notExpected: [CrossCheckRow] = []

        for f in facts {
            guard !f.bib.isEmpty else { continue }
            let s = status(for: f)
            let row = CrossCheckRow(bib: f.bib, name: f.name, status: s, time: f.time)
            switch s {
            case .expected:     expected.append(row)
            case .recorded:     recorded.append(row)
            case .droppedHere:  dropped.append(row)
            case .notExpected:  notExpected.append(row)
            }
        }
        return CrossCheckBoard(expected: expected, recorded: recorded,
                               droppedHere: dropped, notExpected: notExpected)
    }

    /// The action sheet shows the Expected/Not-expected toggle only for runners
    /// that have not been recorded yet (expected or not-expected status).
    static func sheetConfig(for row: CrossCheckRow) -> CrossCheckSheetConfig {
        let togglable = (row.status == .expected || row.status == .notExpected)
        return CrossCheckSheetConfig(bib: row.bib, name: row.name,
                                     showsExpectedToggle: togglable,
                                     isExpected: row.status == .expected)
    }
}
