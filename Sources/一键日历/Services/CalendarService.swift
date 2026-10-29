import Foundation

@MainActor
protocol CalendarService: AnyObject {
    var authorizationStatus: CalendarAccessStatus { get }
    var availableCalendars: [CalendarInfo] { get }
    var hasCloudCalendar: Bool { get }
    func calendar(withIdentifier identifier: String) -> CalendarInfo?
    func defaultCalendar() -> CalendarInfo?

    func requestAccess() async -> Bool
    func refreshAvailableCalendars()
    @discardableResult
    func checkAuthorizationStatus() -> CalendarAccessStatus

    func createReviewEvents(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String?,
        detail: String?
    ) async throws -> CreateEventsResult

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?,
        detail: String?
    ) async throws -> CreateEventsResult

    func undoLastCreation(eventIds: [String]) async -> UndoResult

    func fetchEvents(on date: Date) -> [CalendarEventInfo]
    func fetchEvents(from start: Date, to end: Date) -> [CalendarEventInfo]
    func event(withId id: String) -> CalendarEventInfo?
    @discardableResult
    func deleteEvent(id: String) -> Bool
    func removeEvent(at address: EventAddress, preferredId: String?) -> EventRemovalOutcome
    func event(matching address: EventAddress) -> CalendarEventInfo?
    func searchEvents(query: String, daysAhead: Int) -> [CalendarEventInfo]

    func eventNotes(id: String) -> String?
    @discardableResult
    func updateEventNotes(id: String, notes: String) -> Bool
    @discardableResult
    func updateEventTitle(id: String, title: String) -> Bool
}
