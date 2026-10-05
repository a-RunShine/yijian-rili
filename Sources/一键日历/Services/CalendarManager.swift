import Foundation
import EventKit
import OSLog
import AppKit

/// EventKit adapter（日历 seam 的 macOS 生产实现）。
/// 类型名保留 `CalendarManager`；通过 `CalendarService` 对外，不向调用方泄露 EventKit 类型。
@MainActor
final class CalendarManager: ObservableObject, CalendarService {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.yijianrili.app", category: "CalendarManager")

    @Published private(set) var authorizationStatus: CalendarAccessStatus = .notDetermined
    /// 所有可写日历（含本地），按 source.title 排序，本地排最后
    @Published private(set) var availableCalendars: [CalendarInfo] = []
    /// 是否存在至少一个非本地的可写日历（云账户），用于判断是否需要首次启动引导
    @Published private(set) var hasCloudCalendar: Bool = false
    /// 最近一次创建事件的标识符列表，用于撤销
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
        calendarId: String?
    ) async throws -> CreateEventsResult {
        let reviewDates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        let targetCalendar = try resolveEKCalendar(calendarId: calendarId)

        var result = CreateEventsResult()
        var createdIdentifiers: [String] = []

        for (index, reviewDate) in reviewDates.enumerated() {
            let noteText = String(format: NSLocalizedString("review_count", comment: ""), "\(index + 1)")
            do {
                let hasDuplicate = try checkDuplicate(
                    title: title,
                    date: reviewDate,
                    notes: noteText,
                    in: targetCalendar
                )

                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.startDate = reviewDate
                event.endDate = reviewDate
                event.isAllDay = true
                event.notes = noteText
                event.calendar = targetCalendar

                let alarm = EKAlarm()
                if let alarmDate = self.alarmDate(for: reviewDate) {
                    alarm.absoluteDate = alarmDate
                    event.alarms = [alarm]
                }

                try eventStore.save(event, span: .thisEvent)
                result.created.append(reviewDate)

                if let identifier = event.eventIdentifier {
                    createdIdentifiers.append(identifier)
                }

                if hasDuplicate {
                    result.duplicates.append(reviewDate)
                }

                logger.info("Created event for \(reviewDate.formattedChinese()) in calendar \(targetCalendar.title)")
            } catch {
                result.failed.append((reviewDate, error.localizedDescription))
                logger.error("Failed to create event for \(reviewDate.formattedChinese()): \(error.localizedDescription)")
            }
        }

        if !createdIdentifiers.isEmpty {
            lastCreatedEventIdentifiers = createdIdentifiers
        }

        return result
    }

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?
    ) async throws -> CreateEventsResult {
        let targetCalendar = try resolveEKCalendar(calendarId: calendarId)
        var result = CreateEventsResult()
        var createdIdentifiers: [String] = []

        do {
            let hasDuplicate = try checkDuplicate(title: title, date: date, notes: "", in: targetCalendar)

            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = date
            event.endDate = date
            event.isAllDay = true
            event.notes = ""
            event.calendar = targetCalendar

            let alarm = EKAlarm()
            if let alarmDate = self.alarmDate(for: date) {
                alarm.absoluteDate = alarmDate
                event.alarms = [alarm]
            }

            try eventStore.save(event, span: .thisEvent)
            result.created.append(date)

            if let identifier = event.eventIdentifier {
                createdIdentifiers.append(identifier)
            }

            if hasDuplicate {
                result.duplicates.append(date)
            }

            logger.info("Created single event for \(date.formattedChinese()) in calendar \(targetCalendar.title)")
        } catch {
            result.failed.append((date, error.localizedDescription))
            logger.error("Failed to create single event for \(date.formattedChinese()): \(error.localizedDescription)")
        }

        if !createdIdentifiers.isEmpty {
            lastCreatedEventIdentifiers = createdIdentifiers
        }

        return result
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

    // MARK: - Private

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

    private func checkDuplicate(title: String, date: Date, notes: String, in calendar: EKCalendar) throws -> Bool {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            return false
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: [calendar])
        let events = eventStore.events(matching: predicate)

        return events.contains { $0.title == title && $0.notes == notes }
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
