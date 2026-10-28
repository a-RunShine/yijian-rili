import Foundation

enum HistorySeriesLookup {
    static func entry(containingEventId eventId: String, in history: [HistoryEntry]) -> HistoryEntry? {
        history.first { !$0.createdEventIdentifiers.isEmpty && $0.createdEventIdentifiers.contains(eventId) }
    }

    static func entry(
        matching event: CalendarEventInfo,
        in history: [HistoryEntry],
        calendar: Calendar = .current
    ) -> HistoryEntry? {
        if let exact = entry(containingEventId: event.id, in: history) {
            return exact
        }
        let day = calendar.startOfDay(for: event.start)
        let noteKey = NormalizeNotes.normalize(event.notes)
        return history.first { entry in
            guard entry.type == .review else { return false }
            guard entry.title == event.title else { return false }
            guard dayMatches(entry: entry, day: day, noteKey: noteKey, calendar: calendar) else {
                return false
            }
            return true
        }
    }

    private static func dayMatches(
        entry: HistoryEntry,
        day: Date,
        noteKey: String,
        calendar: Calendar
    ) -> Bool {
        guard let index = reviewIndex(from: noteKey) else {
            return entry.reviewDates.contains { calendar.isDate($0, inSameDayAs: day) }
        }
        let reviewDays = entry.reviewDates.map { calendar.startOfDay(for: $0) }
        guard index < reviewDays.count else { return false }
        return calendar.isDate(reviewDays[index], inSameDayAs: day)
    }

    private static func reviewIndex(from noteKey: String) -> Int? {
        guard noteKey.hasPrefix("第"), noteKey.hasSuffix("次复习") else { return nil }
        let digits = noteKey.dropFirst().dropLast("次复习".count)
        guard let value = Int(digits), value > 0 else { return nil }
        return value - 1
    }
}
