import Foundation

/// 日历 seam：系统日历读写的可替换 interface。
/// 生产：EventKit adapter（`CalendarManager`）；测试：`InMemoryCalendarService`。
/// 对齐 Windows `ICalendarService` 能力集合；不暴露 EventKit 类型。
@MainActor
protocol CalendarService: AnyObject {
    var authorizationStatus: CalendarAccessStatus { get }
    var availableCalendars: [CalendarInfo] { get }
    var hasCloudCalendar: Bool { get }
    var lastCreatedEventIdentifiers: [String] { get }

    func requestAccess() async -> Bool
    func refreshAvailableCalendars()
    /// 刷新并返回当前权限（EventKit adapter 会重新读取系统状态）。
    @discardableResult
    func checkAuthorizationStatus() -> CalendarAccessStatus

    func calendar(withIdentifier identifier: String) -> CalendarInfo?
    func defaultCalendar() -> CalendarInfo?

    func createReviewEvents(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String?
    ) async throws -> CreateEventsResult

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?
    ) async throws -> CreateEventsResult

    func undoLastCreation() async -> UndoResult

    func fetchEvents(on date: Date) -> [CalendarEventInfo]
    @discardableResult
    func deleteEvent(id: String) -> Bool
    func searchEvents(query: String, daysAhead: Int) -> [CalendarEventInfo]
}
