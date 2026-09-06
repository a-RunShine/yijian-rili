import Foundation

/// 周末总结中的一条学习条目（spec F3, F4）。
///
/// 独立于 `HistoryEntry` 的 20 条上限，永久保存（spec F8）。
///
/// 周末双份规则：
/// - 当 `scheduleType == .review` 且 `creationDate` 落在周六或周日时，
///   `appendWeeklyEntry(from:)` 会额外写入一条**预占位**副本：
///   同一 `id`，但 `creationDate` 改为下一周周一 00:00，
///   并标记 `isPreOccupiedNextWeek = true`。
/// - UI 通过该标记显示"下周复习"标签，便于用户区分真实学习条目和预占位。
/// - 单次日程（`.single`）不复制；周一至周五创建的不复制。
/// - 旧数据由 `WeeklyReviewViewModel.performWeekendMigrationIfNeeded()`
///   重新评估是否需要补一份下一周的预占位条目。
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
    /// 周末复习计划双份规则下的"下一周预占位"标记
    /// - `false`：本周（创建所在周）真实条目
    /// - `true`：下一周周一的预占位副本（仅复习计划）
    ///
    /// 解码缺省值为 `false`（spec 旧数据兼容）。
    let isPreOccupiedNextWeek: Bool

    init(id: UUID,
         title: String,
         baseDate: Date,
         scheduleType: HistoryEntry.ScheduleType,
         creationDate: Date,
         isPreOccupiedNextWeek: Bool = false) {
        self.id = id
        self.title = title
        self.baseDate = baseDate
        self.scheduleType = scheduleType
        self.creationDate = creationDate
        self.isPreOccupiedNextWeek = isPreOccupiedNextWeek
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, title, baseDate, scheduleType, creationDate, isPreOccupiedNextWeek
    }

    /// 自定义解码：旧 JSON 缺少 `isPreOccupiedNextWeek` 字段时默认 `false`。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        baseDate = try c.decode(Date.self, forKey: .baseDate)
        scheduleType = try c.decode(HistoryEntry.ScheduleType.self, forKey: .scheduleType)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        isPreOccupiedNextWeek = try c.decodeIfPresent(Bool.self, forKey: .isPreOccupiedNextWeek) ?? false
    }
}
