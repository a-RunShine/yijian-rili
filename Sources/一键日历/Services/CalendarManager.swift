import Foundation
import EventKit
import OSLog

/// EventKit 日历服务单例
/// 负责日历权限管理、复习事件创建、撤销及重复检测
@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.yijianrili.app", category: "CalendarManager")
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    /// 所有可写日历（含本地），按 source.title 排序，本地排最后
    @Published private(set) var availableCalendars: [EKCalendar] = []
    /// 是否存在至少一个非本地的可写日历（云账户），用于判断是否需要首次启动引导
    @Published private(set) var hasCloudCalendar: Bool = false
    /// 最近一次创建事件的标识符列表，用于撤销
    private(set) var lastCreatedEventIdentifiers: [String] = []
    
    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        refreshAvailableCalendars()
    }
    
    /// 重新扫描可写日历（账户变化后调用）
    func refreshAvailableCalendars() {
        let writable = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
        hasCloudCalendar = writable.contains { $0.source.sourceType != .local }
        availableCalendars = writable.sorted { lhs, rhs in
            // 本地日历排最后
            if lhs.source.sourceType == .local && rhs.source.sourceType != .local { return false }
            if lhs.source.sourceType != .local && rhs.source.sourceType == .local { return true }
            if lhs.source.title != rhs.source.title { return lhs.source.title < rhs.source.title }
            return lhs.title < rhs.title
        }
    }
    
    /// 根据 identifier 取日历（取不到说明该账户被删/注销）
    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        return eventStore.calendar(withIdentifier: identifier)
    }
    
    /// 请求日历完整访问权限
    /// - Returns: 是否授权成功
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            refreshAvailableCalendars()
            logger.info("Calendar access granted: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request calendar access: \(error.localizedDescription)")
            authorizationStatus = .denied
            return false
        }
    }
    
    func checkAuthorizationStatus() -> EKAuthorizationStatus {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        return authorizationStatus
    }
    
    /// 创建复习提醒日程
    /// - Parameters:
    ///   - title: 日程标题
    ///   - baseDate: 基准日期
    ///   - intervals: 复习间隔天数数组
    ///   - calendar: 写入的目标日历，nil 时使用系统默认日历
    /// - Returns: 元组（成功创建的日期、重复警告的日期、失败的日期及错误）
    func createReviewEvents(title: String, baseDate: Date, intervals: [Int] = [3, 7, 30], calendar: EKCalendar? = nil) async throws -> (created: [Date], duplicates: [Date], failed: [(Date, Error)]) {
        let reviewDates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        
        let targetCalendar: EKCalendar
        if let chosen = calendar, chosen.allowsContentModifications {
            targetCalendar = chosen
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            targetCalendar = defaultCalendar
        } else {
            logger.error("Default calendar is unavailable")
            throw CalendarError.defaultCalendarUnavailable
        }
        
        var created: [Date] = []
        var duplicates: [Date] = []
        var failed: [(Date, Error)] = []
        var createdIdentifiers: [String] = []
        
        for (index, reviewDate) in reviewDates.enumerated() {
            let noteText = "第\(index + 1)次复习"
            do {
                // Check for duplicates in target calendar only
                let hasDuplicate = try checkDuplicate(title: title, date: reviewDate, notes: noteText, in: targetCalendar)
                
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.startDate = reviewDate
                event.endDate = reviewDate
                event.isAllDay = true
                event.notes = noteText
                event.calendar = targetCalendar
                
                // 当天 9:00 提醒
                let alarm = EKAlarm()
                if let alarmDate = self.alarmDate(for: reviewDate) {
                    alarm.absoluteDate = alarmDate
                    event.alarms = [alarm]
                }
                
                try eventStore.save(event, span: .thisEvent)
                created.append(reviewDate)
                
                if let identifier = event.eventIdentifier {
                    createdIdentifiers.append(identifier)
                }
                
                if hasDuplicate {
                    duplicates.append(reviewDate)
                }
                
                logger.info("Created event for \(reviewDate.formattedChinese()) in calendar \(targetCalendar.title)")
            } catch {
                failed.append((reviewDate, error))
                logger.error("Failed to create event for \(reviewDate.formattedChinese()): \(error.localizedDescription)")
            }
        }
        
        // Store identifiers for undo
        if !createdIdentifiers.isEmpty {
            lastCreatedEventIdentifiers = createdIdentifiers
        }

        return (created, duplicates, failed)
    }

    /// 创建单次日程（非复习计划）
    /// notes 固定为空字符串，复用 `checkDuplicate` 逻辑：
    /// - 同日同 title 且同为单次日程（notes 为空）会被判重
    /// - 与有「第N次复习」notes 的复习日程不会误判
    /// - Parameters:
    ///   - title: 日程标题
    ///   - date: 所选日期
    ///   - calendar: 写入的目标日历，nil 时使用系统默认日历
    /// - Returns: 元组（成功日期、重复警告日期、失败日期及错误）
    func createSingleEvent(title: String, date: Date, calendar: EKCalendar? = nil) async throws -> (created: [Date], duplicates: [Date], failed: [(Date, Error)]) {
        let targetCalendar: EKCalendar
        if let chosen = calendar, chosen.allowsContentModifications {
            targetCalendar = chosen
        } else if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            targetCalendar = defaultCalendar
        } else {
            logger.error("Default calendar is unavailable")
            throw CalendarError.defaultCalendarUnavailable
        }

        var created: [Date] = []
        var duplicates: [Date] = []
        var failed: [(Date, Error)] = []
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
            created.append(date)

            if let identifier = event.eventIdentifier {
                createdIdentifiers.append(identifier)
            }

            if hasDuplicate {
                duplicates.append(date)
            }

            logger.info("Created single event for \(date.formattedChinese()) in calendar \(targetCalendar.title)")
        } catch {
            failed.append((date, error))
            logger.error("Failed to create single event for \(date.formattedChinese()): \(error.localizedDescription)")
        }

        if !createdIdentifiers.isEmpty {
            lastCreatedEventIdentifiers = createdIdentifiers
        }

        return (created, duplicates, failed)
    }
    
    /// 撤销最近一次创建的复习日程
    /// - Returns: 元组（是否成功、已删除数量、已不存在数量）
    func undoLastCreation() async -> (success: Bool, deletedCount: Int, alreadyDeletedCount: Int) {
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
        
        let success = deletedCount > 0
        lastCreatedEventIdentifiers = []
        return (success, deletedCount, alreadyDeletedCount)
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
    
    /// 生成当天 9:00 的提醒时间
    private func alarmDate(for date: Date) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDay)
    }
    
    /// 读取指定日期的事件（所有日历），按「全天优先 + 开始时间」排序
    func fetchEvents(on date: Date) -> [EKEvent] {
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
        return events.sorted { (a, b) -> Bool in
            if a.isAllDay != b.isAllDay {
                return a.isAllDay && !b.isAllDay
            }
            return a.startDate < b.startDate
        }
    }

    /// 在从今天起指定天数内，跨所有日历搜索标题包含关键词的事件
    /// - Parameters:
    ///   - query: 搜索关键词（空字符串返回空数组）
    ///   - daysAhead: 向后搜索的天数，默认 90
    /// - Returns: 匹配的事件，按开始时间升序
    func searchEvents(query: String, daysAhead: Int = 90) -> [EKEvent] {
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
        return matches.sorted { $0.startDate < $1.startDate }
    }
}

enum CalendarError: LocalizedError {
    case defaultCalendarUnavailable
    
    var errorDescription: String? {
        switch self {
        case .defaultCalendarUnavailable:
            return NSLocalizedString("default_calendar_unavailable", comment: "")
        }
    }
}
