import Foundation

/// 周末总结中的一条学习条目（spec F3, F4）。
///
/// 独立于 `HistoryEntry` 的 20 条上限，永久保存（spec F8）。
struct WeeklyEntry: Identifiable, Codable, Equatable {
    /// 与 `HistoryEntry.id` 一对一关联（创建时复制，appendWeeklyEntry 用同一 id）。
    let id: UUID
    let title: String
    /// 用户在创建时选的起始日期（首次学习日期 / 基准学习日期，spec F4）
    let baseDate: Date
    /// 复用 `HistoryEntry.ScheduleType`，保证语义一致
    let scheduleType: HistoryEntry.ScheduleType
    /// 用于按周归属 + 按日期分组（spec F3）
    let creationDate: Date

    init(id: UUID,
         title: String,
         baseDate: Date,
         scheduleType: HistoryEntry.ScheduleType,
         creationDate: Date) {
        self.id = id
        self.title = title
        self.baseDate = baseDate
        self.scheduleType = scheduleType
        self.creationDate = creationDate
    }
}
