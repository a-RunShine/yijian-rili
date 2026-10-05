import Foundation

/// 创建成功 outcomes：日历写入纯成功后的持久化编排。
///
/// - history：cap-20 append
/// - weekly：append（含周末预占位，由 `WeeklyEntryAppending` 实现）
/// - **不变量**：clear/remove history 与 undo **不**触达周末总结；仅纯成功路径调用 `record`
@MainActor
final class CreateSuccessOutcomes {
    private let history: HistoryStore
    private let weekly: WeeklyEntryAppending

    init(history: HistoryStore, weekly: WeeklyEntryAppending) {
        self.history = history
        self.weekly = weekly
    }

    /// 纯成功路径：两侧各写一次。
    func record(_ entry: HistoryEntry) {
        history.add(entry)
        weekly.appendWeeklyEntry(from: entry)
    }

    /// 只清历史；不触达 weekly。
    func clearHistory() {
        history.clear()
    }

    /// 只删历史一条；不触达 weekly。
    func removeHistory(id: UUID) {
        history.remove(id: id)
    }
}
