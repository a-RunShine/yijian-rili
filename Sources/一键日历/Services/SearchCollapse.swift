import Foundation

enum SearchCollapse {
    static func collapse(
        rawHits: [CalendarEventInfo],
        history: [HistoryEntry],
        eventById: (String) -> CalendarEventInfo?
    ) -> [SearchHit] {
        var remaining = rawHits
        var hits: [SearchHit] = []
        var claimed = Set<String>()

        for entry in history where entry.type == .review && !entry.createdEventIdentifiers.isEmpty {
            let overlap = remaining.contains { entry.createdEventIdentifiers.contains($0.id) }
            guard overlap else { continue }

            let members = entry.createdEventIdentifiers.compactMap(eventById).sorted { $0.start < $1.start }
            guard !members.isEmpty else { continue }

            let memberIDs = Set(members.map(\.id))
            claimed.formUnion(memberIDs)
            remaining.removeAll { memberIDs.contains($0.id) }

            hits.append(
                SearchHit(
                    id: "series-\(entry.id.uuidString)",
                    kind: .series(historyEntryID: entry.id),
                    title: entry.title,
                    members: members
                )
            )
        }

        for event in remaining where !claimed.contains(event.id) {
            hits.append(
                SearchHit(
                    id: event.id,
                    kind: .single,
                    title: event.title,
                    members: [event]
                )
            )
        }

        return hits
    }
}
