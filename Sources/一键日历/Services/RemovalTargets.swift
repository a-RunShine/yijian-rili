import Foundation

enum RemovalTargets {
    static func requests(
        entry: HistoryEntry,
        members: [CalendarEventInfo],
        calendar: Calendar = .current
    ) -> [EventRemovalRequest] {
        members.map { event in
            EventRemovalRequest(
                storedId: storedId(for: event, in: entry, calendar: calendar),
                address: EventAddress(event: event)
            )
        }
    }

    static func address(forSlot slot: Int, in entry: HistoryEntry) -> EventAddress? {
        guard entry.reviewDates.indices.contains(slot) else { return nil }
        return EventAddress(
            day: entry.reviewDates[slot],
            title: entry.title,
            notesKey: ReviewNoteKey.key(for: slot, of: entry.type),
            calendarId: nil
        )
    }

    static func slotIndex(of address: EventAddress, in entry: HistoryEntry) -> Int? {
        for (index, day) in entry.reviewDates.enumerated()
        where Calendar.current.isDate(day, inSameDayAs: address.day) {
            guard ReviewNoteKey.key(for: index, of: entry.type) == address.notesKey else { continue }
            return index
        }
        return nil
    }

    static func storedId(
        for event: CalendarEventInfo,
        in entry: HistoryEntry,
        calendar: Calendar = .current
    ) -> String? {
        if let exact = entry.createdEventIdentifiers.first(where: { $0 == event.id }) {
            return exact
        }
        guard let slot = HistorySeriesLookup.reviewIndex(
            of: event,
            in: entry,
            calendar: calendar
        ) else {
            return nil
        }
        return storedId(forSlot: slot, in: entry)
    }

    static func storedId(forSlot slot: Int, in entry: HistoryEntry) -> String? {
        guard entry.createdEventIdentifiers.indices.contains(slot) else { return nil }
        let value = entry.createdEventIdentifiers[slot]
        return value.isEmpty ? nil : value
    }
}
