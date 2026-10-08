import Foundation

@MainActor
protocol CalendarService: AnyObject {
    var authorizationStatus: CalendarAccessStatus { get }
    var availableCalendars: [CalendarInfo] { get }
    var hasCloudCalendar: Bool { get }
    var lastCreatedEventIdentifiers: [String] { get }

    func requestAccess() async -> Bool
    func refreshAvailableCalendars()
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
