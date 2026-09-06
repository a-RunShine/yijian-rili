import Foundation

/// 周次计算工具（spec 周末总结 F2/F5，plan §3.1）。
///
/// **不变式（所有方法共同遵守）：**
/// - **本地时区**：统一用 `Calendar.current.timeZone`（用户系统时区），不做 UTC 转换；
///   跨时区飞行 / 夏令时切换时不重排历史周。
/// - **周首日 = 周一**：固定 `Calendar.current.firstWeekday = 2`，不跟随系统 locale。
/// - **周一 / 周日边界**：周一返回当天的 `00:00:00.000`，周日返回当天的 `23:59:59.999`，
///   闭区间 `[weekStart, weekEnd]`。
enum WeekCalculator {

    /// 计算用的固定 Calendar（周首日强制 Monday）
    static let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    /// 返回 `date` 所在周的周一 `00:00:00.000`（本地时区）
    static func weekStart(for date: Date) -> Date {
        let cal = calendar
        // .weekday 总是 Sunday=1, Monday=2, ..., Saturday=7（不受 firstWeekday 影响）
        let weekday = cal.component(.weekday, from: date)
        // Monday=0, Tuesday=1, ..., Sunday=6
        let daysFromMonday = (weekday + 5) % 7 // Sun=1→6, Mon=2→0, ..., Sat=7→5
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }

    /// 返回 `date` 所在周的周日 `23:59:59.999`（本地时区）
    static func weekEnd(for date: Date) -> Date {
        let cal = calendar
        let start = weekStart(for: date)
        // 周一 00:00 + 6 天 = 周日 00:00
        guard let sundayMidnight = cal.date(byAdding: .day, value: 6, to: start) else {
            return start
        }
        // 取当天 23:59:59.999
        var comps = cal.dateComponents([.year, .month, .day], from: sundayMidnight)
        comps.hour = 23
        comps.minute = 59
        comps.second = 59
        comps.nanosecond = 999_000_000
        return cal.date(from: comps) ?? sundayMidnight
    }

    /// 周稳定 key（基于周一日期的 yyyy-MM-dd），用作笔记字典的键
    static func weekKey(for mondayStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: mondayStart)
    }

    /// 返回 `(start, end, key)` 三元组
    static func weekRange(for date: Date) -> (start: Date, end: Date, key: String) {
        let start = weekStart(for: date)
        let end = weekEnd(for: date)
        let key = weekKey(for: start)
        return (start, end, key)
    }

    /// 周一 ± 7 天，返回新周一的 `00:00:00.000`
    static func addingWeeks(_ n: Int, to mondayStart: Date) -> Date {
        calendar.date(byAdding: .day, value: n * 7, to: mondayStart) ?? mondayStart
    }

    /// 是否是周六或周日（用于周末复习计划双份判定）
    /// - 使用 `WeekCalculator.calendar`（固定周一为周首日）保持与周计算口径一致
    /// - `.weekday` 永远 Sunday=1, Monday=2, ..., Saturday=7（不受 firstWeekday 影响）
    static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 /* Sunday */ || weekday == 7 /* Saturday */
    }

    /// 返回**下一周**周一的 `00:00:00.000`。
    ///
    /// 不论传入日期是周一至周日的哪一天，结果都是 `date` 之后**下一个日历周**的周一 00:00：
    /// - 周一 → +7 天
    /// - 周二至周日 → 计算到下周一的距离
    /// - 仅用作"周末复习计划"双份规则的预占位日期生成。
    static func nextWeekMonday(after date: Date) -> Date {
        let start = weekStart(for: date)
        // start 是当前周周一 00:00；再加 7 天得到下周周一 00:00
        return addingWeeks(1, to: start)
    }
}
