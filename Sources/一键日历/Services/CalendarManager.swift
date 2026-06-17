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
    /// 最近一次创建事件的标识符列表，用于撤销
    private(set) var lastCreatedEventIdentifiers: [String] = []
    
    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    /// 请求日历完整访问权限
    /// - Returns: 是否授权成功
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
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
    /// - Returns: 元组（成功创建的日期、重复警告的日期、失败的日期及错误）
    func createReviewEvents(title: String, baseDate: Date, intervals: [Int] = [3, 7, 30]) async throws -> (created: [Date], duplicates: [Date], failed: [(Date, Error)]) {
        let reviewDates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
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
                // Check for duplicates
                let hasDuplicate = try checkDuplicate(title: title, date: reviewDate, notes: noteText)
                
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.startDate = reviewDate
                event.endDate = reviewDate
                event.isAllDay = true
                event.notes = noteText
                event.calendar = defaultCalendar
                
                try eventStore.save(event, span: .thisEvent)
                created.append(reviewDate)
                
                if let identifier = event.eventIdentifier {
                    createdIdentifiers.append(identifier)
                }
                
                if hasDuplicate {
                    duplicates.append(reviewDate)
                }
                
                logger.info("Created event for \(reviewDate.formattedChinese())")
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
    
    func clearLastCreatedIdentifiers() {
        lastCreatedEventIdentifiers = []
    }
    
    private func checkDuplicate(title: String, date: Date, notes: String) throws -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return false
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.contains { $0.title == title && $0.notes == notes }
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
