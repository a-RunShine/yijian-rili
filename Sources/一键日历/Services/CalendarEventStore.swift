import Foundation

struct StoredCalendarEvent: Sendable, Equatable {
    let id: String
    let title: String
    let day: Date
    let rawNotes: String
}

@MainActor
protocol CalendarEventStore: AnyObject {
    func events(calendarId: String, day: Date) throws -> [StoredCalendarEvent]
    func saveAllDay(calendarId: String, title: String, day: Date, notes: String) throws -> String
}

struct CalendarWriteOutcome: Sendable {
    var result: CreateEventsResult
    var createdEventIds: [String]
}
