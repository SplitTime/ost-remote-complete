import Foundation

/// Pure merge for the live reads list (Approach A): fold a freshly fetched page
/// into the running list, de-duplicating by `id`, keeping newest-first order, and
/// reporting which ids are genuinely new (for highlight) via a high-water-mark.
enum LiveReadsMerge {
    static func merge(existing: [RawTime],
                      incoming: [RawTime],
                      highWaterMark: Int) -> (rows: [RawTime], newIds: [Int], highWaterMark: Int) {
        let existingIds = Set(existing.map { $0.id })

        let newIds = incoming
            .filter { $0.id > highWaterMark && !existingIds.contains($0.id) }
            .map { $0.id }

        var byId = [Int: RawTime]()
        for row in existing { byId[row.id] = row }
        for row in incoming { byId[row.id] = row }

        let rows = byId.values.sorted { $0.id > $1.id }
        let newHwm = rows.first.map { max($0.id, highWaterMark) } ?? highWaterMark

        return (rows, newIds, newHwm)
    }
}
