import Foundation
import EventKit
import OSLog
import AppKit

@MainActor
final class CalendarManager: ObservableObject, CalendarService, CalendarEventStore {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.yijianrili.app", category: "CalendarManager")

    @Published private(set) var authorizationStatus: CalendarAccessStatus = .notDetermined
    @Published private(set) var availableCalendars: [CalendarInfo] = []
    @Published private(set) var hasCloudCalendar: Bool = false
    private(set) var lastCreatedEventIdentifiers: [String] = []

    private init() {
        authorizationStatus = Self.mapAccess(EKEventStore.authorizationStatus(for: .event))
        refreshAvailableCalendars()
    }

    func refreshAvailableCalendars() {
        let writable = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
        hasCloudCalendar = writable.contains { $0.source.sourceType != .local }
        availableCalendars = Self.sortAndMap(writable)
    }

    func calendar(withIdentifier identifier: String) -> CalendarInfo? {
        guard let ek = eventStore.calendar(withIdentifier: identifier),
              ek.allowsContentModifications else { return nil }
        return Self.mapCalendar(ek)
    }

    func defaultCalendar() -> CalendarInfo? {
        guard let ek = eventStore.defaultCalendarForNewEvents else { return nil }
        return Self.mapCalendar(ek)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = Self.mapAccess(EKEventStore.authorizationStatus(for: .event))
            refreshAvailableCalendars()
            logger.info("Calendar access granted: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request calendar access: \(error.localizedDescription)")
            authorizationStatus = .denied
            return false
        }
    }

    @discardableResult
    func checkAuthorizationStatus() -> CalendarAccessStatus {
        authorizationStatus = Self.mapAccess(EKEventStore.authorizationStatus(for: .event))
        return authorizationStatus
    }

    func createReviewEvents(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String?,
        detail: String? = nil
    ) async throws -> CreateEventsResult {
        let targetCalendar = try resolveEKCalendar(calendarId: calendarId)
        let outcome = try CalendarWriteOrchestrator.writeReview(
            title: title,
            baseDate: baseDate,
            intervals: intervals,
            calendarId: targetCalendar.calendarIdentifier,
            store: self,
            detail: detail
        )
        if !outcome.createdEventIds.isEmpty {
            lastCreatedEventIdentifiers = outcome.createdEventIds
        }
        return outcome.result
    }

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?,
        detail: String? = nil
    ) async throws -> CreateEventsResult {
        let targetCalendar = try resolveEKCalendar(calendarId: calendarId)
        let outcome = try CalendarWriteOrchestrator.writeSingle(
            title: title,
            date: date,
            calendarId: targetCalendar.calendarIdentifier,
            store: self,
            detail: detail
        )
        if !outcome.createdEventIds.isEmpty {
            lastCreatedEventIdentifiers = outcome.createdEventIds
        }
        return outcome.result
    }

    func events(calendarId: String, day: Date) throws -> [StoredCalendarEvent] {
        guard let ekCalendar = eventStore.calendar(withIdentifier: calendarId) else { return [] }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: day)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: [ekCalendar]
        )
        return eventStore.events(matching: predicate).map { event in
            StoredCalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "",
                day: cal.startOfDay(for: event.startDate),
                rawNotes: event.notes ?? ""
            )
        }
    }

    func saveAllDay(calendarId: String, title: String, day: Date, notes: String) throws -> String {
        guard let targetCalendar = eventStore.calendar(withIdentifier: calendarId),
              targetCalendar.allowsContentModifications else {
            throw CalendarError.defaultCalendarUnavailable
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = day
        event.endDate = day
        event.isAllDay = true
        event.notes = notes
        event.calendar = targetCalendar

        let alarm = EKAlarm()
        if let alarmDate = self.alarmDate(for: day) {
            alarm.absoluteDate = alarmDate
            event.alarms = [alarm]
        }

        try eventStore.save(event, span: .thisEvent)
        logger.info("Created event for \(day.formattedChinese()) in calendar \(targetCalendar.title)")
        return event.eventIdentifier ?? UUID().uuidString
    }

    func undoLastCreation() async -> UndoResult {
        var deletedCount = 0
        var alreadyDeletedCount = 0

        for identifier in lastCreatedEventIdentifiers {
            if let event = eventStore.event(withIdentifier: identifier) {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                    deletedCount += 1
                    logger.info("Undo: deleted event with identifier \(identifier)")
                } catch {
                    logger.error("Undo: failed to delete event \(identifier): \(error.localizedDescription)")
                }
            } else {
                alreadyDeletedCount += 1
                logger.warning("Undo: event \(identifier) already deleted or not found")
            }
        }

        lastCreatedEventIdentifiers = []
        return UndoResult(
            success: deletedCount > 0,
            deletedCount: deletedCount,
            alreadyDeletedCount: alreadyDeletedCount
        )
    }

    func fetchEvents(on date: Date) -> [CalendarEventInfo] {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            logger.info("fetchEvents skipped: status = \(String(describing: status))")
            return []
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        logger.info("fetchEvents on \(startOfDay.formattedChinese()): found \(events.count) events")
        return events
            .sorted { (a, b) -> Bool in
                if a.isAllDay != b.isAllDay {
                    return a.isAllDay && !b.isAllDay
                }
                return a.startDate < b.startDate
            }
            .map { Self.mapEvent($0) }
    }

    @discardableResult
    func deleteEvent(id: String) -> Bool {
        guard let event = eventStore.event(withIdentifier: id) else {
            logger.warning("deleteEvent: event \(id) not found")
            return false
        }
        do {
            try eventStore.remove(event, span: .thisEvent)
            logger.info("Deleted event \(id) for \(event.startDate.formattedChinese())")
            return true
        } catch {
            logger.error("Failed to delete event: \(error.localizedDescription)")
            return false
        }
    }

    func searchEvents(query: String, daysAhead: Int) -> [CalendarEventInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            logger.info("searchEvents skipped: status = \(String(describing: status))")
            return []
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startOfToday) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfToday, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let matches = events.filter { event in
            guard let title = event.title else { return false }
            return title.localizedCaseInsensitiveContains(trimmed)
        }
        logger.info("searchEvents query=\(trimmed) daysAhead=\(daysAhead): \(matches.count)/\(events.count) matched")
        return matches.sorted { $0.startDate < $1.startDate }.map { Self.mapEvent($0) }
    }

    private func resolveEKCalendar(calendarId: String?) throws -> EKCalendar {
        if let calendarId, !calendarId.isEmpty,
           let chosen = eventStore.calendar(withIdentifier: calendarId),
           chosen.allowsContentModifications {
            return chosen
        }
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            return defaultCalendar
        }
        logger.error("Default calendar is unavailable")
        throw CalendarError.defaultCalendarUnavailable
    }

    private func alarmDate(for date: Date) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)
    }

    private static func mapAccess(_ status: EKAuthorizationStatus) -> CalendarAccessStatus {
        switch status {
        case .fullAccess: return .fullAccess
        case .denied: return .denied
        case .restricted: return .restricted
        case .writeOnly: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private static func mapSourceKind(_ type: EKSourceType) -> CalendarSourceKind {
        type == .local ? .local : .cloud
    }

    private static func colorHex(from cgColor: CGColor) -> String? {
        guard let ns = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) else { return nil }
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func mapCalendar(_ calendar: EKCalendar) -> CalendarInfo {
        CalendarInfo(
            identifier: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            sourceKind: mapSourceKind(calendar.source.sourceType),
            allowsContentModifications: calendar.allowsContentModifications,
            colorHex: colorHex(from: calendar.cgColor)
        )
    }

    private static func mapEvent(_ event: EKEvent) -> CalendarEventInfo {
        CalendarEventInfo(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            notes: event.notes,
            calendarId: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            calendarSourceTitle: event.calendar.source.title,
            colorHex: colorHex(from: event.calendar.cgColor)
        )
    }

    private static func sortAndMap(_ calendars: [EKCalendar]) -> [CalendarInfo] {
        calendars
            .sorted { lhs, rhs in
                if lhs.source.sourceType == .local && rhs.source.sourceType != .local { return false }
                if lhs.source.sourceType != .local && rhs.source.sourceType == .local { return true }
                if lhs.source.title != rhs.source.title { return lhs.source.title < rhs.source.title }
                return lhs.title < rhs.title
            }
            .map { mapCalendar($0) }
    }
}
