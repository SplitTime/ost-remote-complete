// OST Tracker/Swift/AutoSync/AutoSyncStatus.swift
import Foundation

enum AutoSyncState: String {
    case disabled, synced, pending, syncing, failed, offline
}

struct AutoSyncStatus: Equatable {
    let state: AutoSyncState
    let pendingCount: Int
    let lastSyncDate: Date?
}

extension AutoSyncStatus {
    var stripText: String {
        switch state {
        case .disabled: return ""
        case .synced:
            let when = lastSyncDate.map { AutoSyncStatus.timeFormatter.string(from: $0) } ?? ""
            return "Auto Sync · All synced · \(when)"
        case .pending: return "Auto Sync · \(pendingCount) to sync…"
        case .syncing: return "Auto Sync · Syncing \(pendingCount)…"
        case .failed:  return "Sync failed · retrying soon · \(pendingCount) pending"
        case .offline: return "Offline · \(pendingCount) waiting to sync"
        }
    }

    var isTappableForRetry: Bool { state == .failed || state == .offline }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
}
