import Foundation

enum DayNavigationStep: Equatable {
    case previousDay
    case nextDay
    case previousWeek
    case nextWeek
}

enum DayNavigation {
    static func day(from date: Date, step: DayNavigationStep, calendar: Calendar = WeekCalculator.calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        let offset: Int
        switch step {
        case .previousDay:
            offset = -1
        case .nextDay:
            offset = 1
        case .previousWeek:
            offset = -7
        case .nextWeek:
            offset = 7
        }
        return calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }
}
