import Foundation

@MainActor
enum CalendarWriteOrchestrator {
    static func writeReview(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String,
        store: CalendarEventStore,
        detail: String? = nil
    ) throws -> CalendarWriteOutcome {
        guard IntervalRules.validate(intervals) else {
            throw CalendarError.invalidIntervals
        }
        let dates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        let items = dates.enumerated().map { index, date in
            (date: date, notesKey: ReviewNoteKey.forIndex(index))
        }
        return try writeAllDayEvents(
            title: title,
            items: items,
            calendarId: calendarId,
            store: store,
            detail: detail
        )
    }

    static func writeSingle(
        title: String,
        date: Date,
        calendarId: String,
        store: CalendarEventStore,
        detail: String? = nil
    ) throws -> CalendarWriteOutcome {
        let day = Calendar.current.startOfDay(for: date)
        return try writeAllDayEvents(
            title: title,
            items: [(date: day, notesKey: ReviewNoteKey.single)],
            calendarId: calendarId,
            store: store,
            detail: detail
        )
    }

    static func writeAllDayEvents(
        title: String,
        items: [(date: Date, notesKey: String)],
        calendarId: String,
        store: CalendarEventStore,
        detail: String? = nil
    ) throws -> CalendarWriteOutcome {
        var result = CreateEventsResult()
        var createdIds: [String] = []

        for item in items {
            let day = Calendar.current.startOfDay(for: item.date)
            do {
                let existing = try store.events(calendarId: calendarId, day: day)
                if DuplicateMatch.isDuplicate(
                    title: title,
                    day: day,
                    notesKey: item.notesKey,
                    existing: existing
                ) {
                    result.duplicates.append(day)
                }
                let notes = ReviewNotes.compose(key: item.notesKey, detail: detail)
                let id = try store.saveAllDay(
                    calendarId: calendarId,
                    title: title,
                    day: day,
                    notes: notes
                )
                result.created.append(day)
                createdIds.append(id)
            } catch {
                result.failed.append((day, error.localizedDescription))
            }
        }

        return CalendarWriteOutcome(result: result, createdEventIds: createdIds)
    }
}
