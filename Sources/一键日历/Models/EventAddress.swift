import Foundation

struct EventAddress: Hashable, Sendable {
    let day: Date
    let title: String
    let notesKey: String
    let calendarId: String?

    init(day: Date, title: String, notesKey: String, calendarId: String?) {
        self.day = Calendar.current.startOfDay(for: day)
        self.title = title
        self.notesKey = NormalizeNotes.normalize(notesKey)
        self.calendarId = calendarId
    }

    init(event: CalendarEventInfo) {
        self.init(
            day: event.start,
            title: event.title,
            notesKey: event.notes ?? "",
            calendarId: event.calendarId
        )
    }

    func matches(_ event: CalendarEventInfo) -> Bool {
        guard title == event.title else { return false }
        if let calendarId, let other = event.calendarId, calendarId != other {
            return false
        }
        guard Calendar.current.isDate(event.start, inSameDayAs: day) else { return false }
        return NormalizeNotes.normalize(event.notes) == notesKey
    }
}

enum EventRemovalRefusal: Equatable, Sendable {
    case noAccess
    case readOnlyCalendar
    case seamRefused(String)

    var message: String {
        switch self {
        case .noAccess:
            return NSLocalizedString("delete_failed_no_access", comment: "")
        case .readOnlyCalendar:
            return NSLocalizedString("delete_failed_read_only", comment: "")
        case .seamRefused(let detail):
            return String(
                format: NSLocalizedString("delete_failed_seam", comment: ""),
                detail
            )
        }
    }
}

enum EventRemovalOutcome: Equatable, Sendable {
    case removed(eventId: String)
    case alreadyAbsent
    case refused(EventRemovalRefusal)

    var removedEventId: String? {
        if case .removed(let id) = self { return id }
        return nil
    }

    var didRemoveEvent: Bool { removedEventId != nil }

    var isRefusal: Bool {
        if case .refused = self { return true }
        return false
    }
}

struct EventRemovalRequest: Sendable {
    let storedId: String?
    let address: EventAddress

    init(storedId: String?, address: EventAddress) {
        self.storedId = storedId
        self.address = address
    }
}

struct RemovalTarget: Equatable, Sendable {
    let storedId: String?
    let address: EventAddress
}
