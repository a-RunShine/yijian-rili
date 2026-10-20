import Foundation

enum MonthPreviewOverflow: Equatable {
    case none
    case nextMonth(Int)
    case outsideWindow(Int)

    func localizedLine() -> String? {
        switch self {
        case .none:
            return nil
        case .nextMonth(let count):
            return String(format: NSLocalizedString("month_overflow_next", comment: ""), count)
        case .outsideWindow(let count):
            return String(format: NSLocalizedString("month_overflow_outside", comment: ""), count)
        }
    }
}

enum MonthPreviewWindow {
    static func overflow(reviewDates: [Date], visibleMonth: Date) -> MonthPreviewOverflow {
        let calendar = WeekCalculator.calendar
        let visibleDays = Set(MonthGrid.cells(in: visibleMonth, today: .distantPast).map(\.date))
        var seen = Set<Date>()
        var outside: [Date] = []
        for date in reviewDates {
            let day = calendar.startOfDay(for: date)
            guard seen.insert(day).inserted else { continue }
            if !visibleDays.contains(day) {
                outside.append(day)
            }
        }
        guard !outside.isEmpty else { return .none }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart(visibleMonth, calendar)) else {
            return .outsideWindow(outside.count)
        }
        let nextParts = calendar.dateComponents([.year, .month], from: nextMonth)
        let allInNextMonth = outside.allSatisfy { day in
            let parts = calendar.dateComponents([.year, .month], from: day)
            return parts.year == nextParts.year && parts.month == nextParts.month
        }
        return allInNextMonth ? .nextMonth(outside.count) : .outsideWindow(outside.count)
    }

    static func ordinals(for reviewDates: [Date]) -> [Date: Int] {
        let calendar = WeekCalculator.calendar
        var ordinals: [Date: Int] = [:]
        for (index, date) in reviewDates.enumerated() {
            let day = calendar.startOfDay(for: date)
            if ordinals[day] == nil {
                ordinals[day] = index + 1
            }
        }
        return ordinals
    }

    static func shadeOpacity(forOrdinal ordinal: Int) -> Double {
        let stepped = 0.14 + Double(ordinal - 1) * 0.04
        return min(0.40, stepped)
    }

    private static func monthStart(_ month: Date, _ calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: month)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: month)
    }
}
