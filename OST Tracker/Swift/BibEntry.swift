//
//  BibEntry.swift
//  OST Tracker
//
//  Pure, side-effect-free rules for bib entry creation, shared by the tracker and
//  edit-entry screens. Extracted so the empty-bib block is unit-testable without
//  driving the IBAction-wired view controllers.
//

import Foundation

enum BibEntry {

    /// A bib can be recorded only when the field holds at least one character.
    /// An empty or nil field is blocked: no entry is created.
    static func isRecordable(_ bibText: String?) -> Bool {
        !(bibText?.isEmpty ?? true)
    }
}
