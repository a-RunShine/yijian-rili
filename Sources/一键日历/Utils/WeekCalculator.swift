import Foundation

enum WeekCalculator {

    static let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    static func weekStart(for date: Date) -> Date {
        let cal = calendar
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    static func weekEnd(for date: Date) -> Date {
        let cal = calendar
        let start = weekStart(for: date)
        guard let sundayMidnight = cal.date(byAdding: .day, value: 6, to: start) else {
            return start
        }
        var comps = cal.dateComponents([.year, .month, .day], from: sundayMidnight)
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        comps.nanosecond = 999_000_000
        return cal.date(from: comps) ?? sundayMidnight
    }

    static func weekKey(for mondayStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: mondayStart)
    }

    static func weekRange(for date: Date) -> (start: Date, end: Date, key: String) {
        let start = weekStart(for: date)
        let end = weekEnd(for: date)
        let key = weekKey(for: start)
        return (start, end, key)
    }

    static func addingWeeks(_ n: Int, to mondayStart: Date) -> Date {
        calendar.date(byAdding: .day, value: n * 7, to: mondayStart) ?? mondayStart
    }

    static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    static func nextWeekMonday(after date: Date) -> Date {
        let start = weekStart(for: date)
        return addingWeeks(1, to: start)
    }
}
