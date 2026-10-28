import Foundation

enum DayEventProjection {
    static func project(
        dayEvents: [CalendarEventInfo],
        history: [HistoryEntry],
        candidates: [CalendarEventInfo],
        eventById: (String) -> CalendarEventInfo?
    ) -> [SearchHit] {
        dayEvents.map { event in
            guard let entry = HistorySeriesLookup.entry(matching: event, in: history),
                  entry.type == .review else {
                return SearchHit(
                    id: event.id,
                    kind: .single,
                    title: event.title,
                    members: [event]
                )
            }

            var members = HistorySeriesLookup.members(of: entry, among: candidates)
            if members.isEmpty {
                members = entry.createdEventIdentifiers
                    .compactMap(eventById)
                    .sorted { $0.start < $1.start }
            }
            guard !members.isEmpty else {
                return SearchHit(
                    id: event.id,
                    kind: .single,
                    title: event.title,
                    members: [event]
                )
            }

            return SearchHit(
                id: event.id,
                kind: .series(historyEntryID: entry.id),
                title: entry.title,
                members: members
            )
        }
    }
}
