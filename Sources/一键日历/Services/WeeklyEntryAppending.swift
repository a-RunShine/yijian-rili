import Foundation

/// 周末总结 append seam：创建成功 outcomes 只依赖此窄 interface。
protocol WeeklyEntryAppending: AnyObject {
    func appendWeeklyEntry(from historyEntry: HistoryEntry)
}
