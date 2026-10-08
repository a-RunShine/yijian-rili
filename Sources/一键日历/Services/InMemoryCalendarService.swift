import Foundation

@MainActor
final class InMemoryCalendarService: CalendarService, CalendarEventStore {
    private var calendars: [CalendarInfo]
    private var events: [CalendarEventInfo] = []
    private var lastCreated: [String] = []
    private var seq = 0

    private(set) var authorizationStatus: CalendarAccessStatus
    private(set) var lastCreatedEventIdentifiers: [String] = []

    var availableCalendars: [CalendarInfo] {
        authorizationStatus == .fullAccess ? Self.sortCalendars(calendars) : []
    }

    var hasCloudCalendar: Bool {
        availableCalendars.contains { $0.sourceKind == .cloud }
    }

    init(grantAccessByDefault: Bool = true) {
        authorizationStatus = grantAccessByDefault ? .fullAccess : .notDetermined
        calendars = [
            CalendarInfo(
                identifier: "local-default",
                title: "本地日历",
                sourceTitle: "本地",
                sourceKind: .local,
                allowsContentModifications: true,
                colorHex: "#8E8E93"
            ),
            CalendarInfo(
                identifier: "outlook-default",
                title: "日历",
                sourceTitle: "Outlook",
                sourceKind: .cloud,
                allowsContentModifications: true,
                colorHex: "#0078D4"
            )
        ]
    }

    func requestAccess() async -> Bool {
        authorizationStatus = .fullAccess
        return true
    }

    func refreshAvailableCalendars() {}

    @discardableResult
    func checkAuthorizationStatus() -> CalendarAccessStatus {
        authorizationStatus
    }

    func calendar(withIdentifier identifier: String) -> CalendarInfo? {
        availableCalendars.first { $0.identifier == identifier }
    }

    func defaultCalendar() -> CalendarInfo? {
        availableCalendars.first { $0.sourceKind == .cloud }
            ?? availableCalendars.first
    }

    func createReviewEvents(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String?
    ) async throws -> CreateEventsResult {
        try ensureAccess()
        let calendar = try resolveCalendar(calendarId)
        let outcome = try CalendarWriteOrchestrator.writeReview(
            title: title,
            baseDate: baseDate,
            intervals: intervals,
            calendarId: calendar.identifier,
            store: self
        )
        if !outcome.createdEventIds.isEmpty {
            lastCreated = outcome.createdEventIds
            lastCreatedEventIdentifiers = outcome.createdEventIds
        }
        return outcome.result
    }

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?
    ) async throws -> CreateEventsResult {
        try ensureAccess()
        let calendar = try resolveCalendar(calendarId)
        let outcome = try CalendarWriteOrchestrator.writeSingle(
            title: title,
            date: date,
            calendarId: calendar.identifier,
            store: self
        )
        if !outcome.createdEventIds.isEmpty {
            lastCreated = outcome.createdEventIds
            lastCreatedEventIdentifiers = outcome.createdEventIds
        }
        return outcome.result
    }

    func events(calendarId: String, day: Date) throws -> [StoredCalendarEvent] {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.compactMap { event in
            guard event.calendarId == calendarId,
                  event.start >= start, event.start < end else { return nil }
            return StoredCalendarEvent(
                id: event.id,
                title: event.title,
                day: Calendar.current.startOfDay(for: event.start),
                rawNotes: event.notes ?? ""
            )
        }
    }

    func saveAllDay(calendarId: String, title: String, day: Date, notesKey: String) throws -> String {
        guard let calendar = calendars.first(where: { $0.identifier == calendarId }) else {
            throw CalendarError.defaultCalendarUnavailable
        }
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let rawNotes = Self.storageNotes(from: notesKey)
        let id = nextId()
        events.append(
            CalendarEventInfo(
                id: id,
                title: title,
                start: start,
                end: end,
                isAllDay: true,
                notes: rawNotes,
                calendarId: calendar.identifier,
                calendarTitle: calendar.title,
                calendarSourceTitle: calendar.sourceTitle,
                colorHex: calendar.colorHex
            )
        )
        return id
    }

    func undoLastCreation() async -> UndoResult {
        var deleted = 0
        var missing = 0
        for id in lastCreated {
            let before = events.count
            events.removeAll { $0.id == id }
            if events.count < before {
                deleted += before - events.count
            } else {
                missing += 1
            }
        }
        lastCreated = []
        lastCreatedEventIdentifiers = []
        return UndoResult(
            success: deleted > 0,
            deletedCount: deleted,
            alreadyDeletedCount: missing
        )
    }

    func fetchEvents(on date: Date) -> [CalendarEventInfo] {
        guard authorizationStatus == .fullAccess else { return [] }
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events
            .filter { $0.start < end && $0.end > start }
            .sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay && !$1.isAllDay }
                return $0.start < $1.start
            }
    }

    @discardableResult
    func deleteEvent(id: String) -> Bool {
        let before = events.count
        events.removeAll { $0.id == id }
        return events.count < before
    }

    func searchEvents(query: String, daysAhead: Int) -> [CalendarEventInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, authorizationStatus == .fullAccess else { return [] }
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: start) else { return [] }
        return events
            .filter { $0.start >= start && $0.start < end }
            .filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
            .sorted { $0.start < $1.start }
    }

    private func nextId() -> String {
        seq += 1
        return "evt-\(seq)"
    }

    private func ensureAccess() throws {
        guard authorizationStatus == .fullAccess else {
            throw CalendarError.accessDenied
        }
    }

    private func resolveCalendar(_ calendarId: String?) throws -> CalendarInfo {
        if let calendarId, !calendarId.isEmpty, let chosen = calendar(withIdentifier: calendarId) {
            return chosen
        }
        guard let fallback = defaultCalendar() else {
            throw CalendarError.defaultCalendarUnavailable
        }
        return fallback
    }

    private static func storageNotes(from notesKey: String) -> String {
        if notesKey.isEmpty {
            return "提醒建议：当天 09:00"
        }
        return "\(notesKey)\n提醒建议：当天 09:00"
    }

    private static func sortCalendars(_ calendars: [CalendarInfo]) -> [CalendarInfo] {
        calendars.sorted { lhs, rhs in
            if lhs.sourceKind == .local && rhs.sourceKind != .local { return false }
            if lhs.sourceKind != .local && rhs.sourceKind == .local { return true }
            if lhs.sourceTitle != rhs.sourceTitle { return lhs.sourceTitle < rhs.sourceTitle }
            return lhs.title < rhs.title
        }
    }
}
