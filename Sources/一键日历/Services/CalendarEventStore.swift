import Foundation

/// store seam 上可比对的已存事件字段（不含 EventKit 类型）。
struct StoredCalendarEvent: Sendable, Equatable {
    let id: String
    let title: String
    /// 日历日起点（startOfDay）
    let day: Date
    let rawNotes: String
}

/// 窄日历 store seam：写入日历编排只依赖查找与保存全天事件。
@MainActor
protocol CalendarEventStore: AnyObject {
    func events(calendarId: String, day: Date) throws -> [StoredCalendarEvent]
    /// 保存全天事件；`notesKey` 为复习备注键（adapter 可附加提醒展示文案）。
    func saveAllDay(calendarId: String, title: String, day: Date, notesKey: String) throws -> String
}

/// 写入日历编排的产出（结果 + 新建 id，供撤销）。
struct CalendarWriteOutcome: Sendable {
    var result: CreateEventsResult
    var createdEventIds: [String]
}
