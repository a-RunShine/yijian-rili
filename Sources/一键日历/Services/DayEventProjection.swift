import Foundation

enum DayEventProjection {
    static func project(
        dayEvents: [CalendarEventInfo],
        history: [HistoryEntry],
        eventById: (String) -> CalendarEventInfo?
    ) -> [SearchHit] {
        dayEvents.map { event in
            guard let entry = HistorySeriesLookup.entry(containingEventId: event.id, in: history),
                  entry.type == .review,
                  !entry.createdEventIdentifiers.isEmpty else {
                return SearchHit(
                    id: event.id,
                    kind: .single,
                    title: event.title,
                    members: [event]
                )
            }

            let members = entry.createdEventIdentifiers
                .compactMap(eventById)
                .sorted { $0.start < $1.start }
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
