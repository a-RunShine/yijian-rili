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
        return history.first { entry in
            guard entry.type == .review, entry.title == event.title else { return false }
            return indexOfReviewDay(for: event, in: entry, calendar: calendar) != nil
        }
    }

    static func members(
        of entry: HistoryEntry,
        among candidates: [CalendarEventInfo],
        calendar: Calendar = .current
    ) -> [CalendarEventInfo] {
        let byId = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let byIdentifier = entry.createdEventIdentifiers.compactMap { byId[$0] }
        if byIdentifier.count == entry.createdEventIdentifiers.count, !byIdentifier.isEmpty {
            return byIdentifier.sorted { $0.start < $1.start }
        }
        return resolvedByAttributes(entry, among: candidates, calendar: calendar)
    }

    static func resolvedByAttributes(
        _ entry: HistoryEntry,
        among candidates: [CalendarEventInfo],
        calendar: Calendar = .current
    ) -> [CalendarEventInfo] {
        var usedDays = Set<Date>()
        var resolved: [CalendarEventInfo] = []
        for day in entry.reviewDates {
            let target = calendar.startOfDay(for: day)
            guard !usedDays.contains(target) else { continue }
            guard let match = candidates.first(where: { candidate in
                candidate.title == entry.title
                    && calendar.isDate(candidate.start, inSameDayAs: target)
            }) else { continue }
            usedDays.insert(target)
            resolved.append(match)
        }
        return resolved.sorted { $0.start < $1.start }
    }

    static func missingReviewDays(of entry: HistoryEntry, calendar: Calendar = .current) -> [Date] {
        entry.reviewDates.map { calendar.startOfDay(for: $0) }
    }

    static func stableKey(for event: CalendarEventInfo, in history: [HistoryEntry], calendar: Calendar = .current) -> String {
        guard let entry = entry(matching: event, in: history),
              entry.type == .review,
              let index = indexOfReviewDay(for: event, in: entry, calendar: calendar) else {
            return legacyKey(for: event.id)
        }
        return seriesKey(entryID: entry.id, index: index)
    }

    static func seriesKey(entryID: UUID, index: Int) -> String {
        "series:\(entryID.uuidString):\(index)"
    }

    static func legacyKey(for eventId: String) -> String {
        "event:\(eventId)"
    }

    static func reviewIndex(
        of event: CalendarEventInfo,
        in entry: HistoryEntry,
        calendar: Calendar = .current
    ) -> Int? {
        indexOfReviewDay(for: event, in: entry, calendar: calendar)
    }

    private static func indexOfReviewDay(
        for event: CalendarEventInfo,
        in entry: HistoryEntry,
        calendar: Calendar
    ) -> Int? {
        let day = calendar.startOfDay(for: event.start)
        let reviewDays = entry.reviewDates.map { calendar.startOfDay(for: $0) }
        guard let position = reviewDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: day) }) else {
            return nil
        }
        let noteKey = NormalizeNotes.normalize(event.notes)
        guard let claimed = declaredIndex(from: noteKey) else { return position }
        return claimed == position ? position : nil
    }

    private static func declaredIndex(from noteKey: String) -> Int? {
        guard noteKey.hasPrefix("第"), noteKey.hasSuffix("次复习") else { return nil }
        let digits = noteKey.dropFirst().dropLast("次复习".count)
        guard let value = Int(digits), value > 0 else { return nil }
        return value - 1
    }
}
