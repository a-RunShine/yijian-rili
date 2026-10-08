import Foundation

/// 进程内日历 adapter，对齐 Windows `InMemoryCalendarService`。
/// 供单测与无 EventKit 环境验证写入日历 / 撤销 / 搜索流程。
@MainActor
final class InMemoryCalendarService: CalendarService {
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

    func refreshAvailableCalendars() {
        // no-op：样例日历固定
    }

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
        let dates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        var result = CreateEventsResult()
        var createdIds: [String] = []

        for (index, date) in dates.enumerated() {
            let notes = Self.reviewNote(for: index)
            if hasDuplicate(title: title, date: date, notes: notes, calendarId: calendar.identifier) {
                result.duplicates.append(date)
            }
            let id = nextId()
            events.append(
                CalendarEventInfo(
                    id: id,
                    title: title,
                    start: Calendar.current.startOfDay(for: date),
                    end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date,
                    isAllDay: true,
                    notes: notes,
                    calendarId: calendar.identifier,
                    calendarTitle: calendar.title,
                    calendarSourceTitle: calendar.sourceTitle,
                    colorHex: calendar.colorHex
                )
            )
            result.created.append(date)
            createdIds.append(id)
        }

        if !createdIds.isEmpty {
            lastCreated = createdIds
            lastCreatedEventIdentifiers = createdIds
        }
        return result
    }

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?
    ) async throws -> CreateEventsResult {
        try ensureAccess()
        let calendar = try resolveCalendar(calendarId)
        var result = CreateEventsResult()
        let day = Calendar.current.startOfDay(for: date)

        if hasDuplicate(title: title, date: day, notes: "", calendarId: calendar.identifier) {
            result.duplicates.append(day)
        }

        let id = nextId()
        events.append(
            CalendarEventInfo(
                id: id,
                title: title,
                start: day,
                end: Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day,
                isAllDay: true,
                notes: "",
                calendarId: calendar.identifier,
                calendarTitle: calendar.title,
                calendarSourceTitle: calendar.sourceTitle,
                colorHex: calendar.colorHex
            )
        )
        result.created.append(day)
        lastCreated = [id]
        lastCreatedEventIdentifiers = [id]
        return result
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

    // MARK: - Private

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

    private func hasDuplicate(title: String, date: Date, notes: String, calendarId: String) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return false }
        return events.contains {
            $0.calendarId == calendarId
                && $0.start >= start && $0.start < end
                && $0.title == title
                && ($0.notes ?? "") == notes
        }
    }

    private static func reviewNote(for zeroBasedIndex: Int) -> String {
        String(format: NSLocalizedString("review_count", comment: ""), "\(zeroBasedIndex + 1)")
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
