import Foundation

struct MonthCell: Equatable {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isWeekend: Bool
}

enum MonthGrid {
    static func cells(in month: Date, today: Date) -> [MonthCell] {
        let calendar = WeekCalculator.calendar
        let parts = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: parts) else { return [] }
        let start = WeekCalculator.weekStart(for: firstOfMonth)
        let todayStart = calendar.startOfDay(for: today)
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let cellParts = calendar.dateComponents([.year, .month], from: dayStart)
            return MonthCell(
                date: dayStart,
                isInDisplayedMonth: cellParts.year == parts.year && cellParts.month == parts.month,
                isToday: dayStart == todayStart,
                isWeekend: WeekCalculator.isWeekend(dayStart)
            )
        }
    }
}
