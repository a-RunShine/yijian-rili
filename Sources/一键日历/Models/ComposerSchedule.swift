import Foundation

enum ComposerPresetSelection: Equatable {
    case classic
    case exam
    case daily
    case custom(name: String?)
}

enum ComposerSchedule {
    static func presetSelection(intervals: [Int], savedPresets: [CustomPreset]) -> ComposerPresetSelection {
        if let preset = IntervalPreset.allCases.first(where: { $0.intervals == intervals }) {
            switch preset {
            case .classic:
                return .classic
            case .exam:
                return .exam
            case .daily:
                return .daily
            }
        }
        return .custom(name: savedPresets.first { $0.intervals == intervals }?.name)
    }

    static func daysOutsideMonthGrid(month: Date, dates: [Date]) -> Int {
        let calendar = WeekCalculator.calendar
        let visible = Set(MonthGrid.cells(in: month, today: month).map(\.date))
        return dates.reduce(into: 0) { count, date in
            if !visible.contains(calendar.startOfDay(for: date)) {
                count += 1
            }
        }
    }
}
