import Foundation
import EventKit
import OSLog

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "com.yijianrili.app", category: "CalendarManager")
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
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
    
    func createReviewEvents(title: String, baseDate: Date) async throws -> (created: [Date], duplicates: [Date], failed: [(Date, Error)]) {
        let calendar = Calendar.current
        let reviewDates = [
            calendar.date(byAdding: .day, value: 3, to: baseDate)!,
            calendar.date(byAdding: .day, value: 7, to: baseDate)!,
            calendar.date(byAdding: .day, value: 30, to: baseDate)!
        ]
        
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            logger.error("Default calendar is unavailable")
            throw CalendarError.defaultCalendarUnavailable
        }
        
        var created: [Date] = []
        var duplicates: [Date] = []
        var failed: [(Date, Error)] = []
        
        for (index, reviewDate) in reviewDates.enumerated() {
            do {
                // Check for duplicates
                let hasDuplicate = try checkDuplicate(title: title, date: reviewDate)
                
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.startDate = reviewDate
                event.endDate = reviewDate
                event.isAllDay = true
                event.notes = "第\(index + 1)次复习"
                event.calendar = defaultCalendar
                
                try eventStore.save(event, span: .thisEvent)
                created.append(reviewDate)
                
                if hasDuplicate {
                    duplicates.append(reviewDate)
                }
                
                logger.info("Created event for \(reviewDate.formattedChinese())")
            } catch {
                failed.append((reviewDate, error))
                logger.error("Failed to create event for \(reviewDate.formattedChinese()): \(error.localizedDescription)")
            }
        }
        
        return (created, duplicates, failed)
    }
    
    private func checkDuplicate(title: String, date: Date) throws -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.contains { $0.title == title }
    }
}

enum CalendarError: LocalizedError {
    case defaultCalendarUnavailable
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .defaultCalendarUnavailable:
            return "系统默认日历不可用，请检查日历设置"
        case .permissionDenied:
            return "日历权限被拒绝，请在系统设置中开启权限"
        }
    }
}
