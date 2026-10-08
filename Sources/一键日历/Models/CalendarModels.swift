import Foundation

enum CalendarAccessStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
}

enum CalendarSourceKind: Equatable, Sendable {
    case local
    case cloud
    case unknown
}

struct CalendarInfo: Identifiable, Hashable, Sendable {
    var id: String { identifier }

    let identifier: String
    let title: String
    let sourceTitle: String
    let sourceKind: CalendarSourceKind
    let allowsContentModifications: Bool
    let colorHex: String?

    var displayName: String { "\(sourceTitle) → \(title)" }
}

struct CalendarEventInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let notes: String?
    let calendarId: String?
    let calendarTitle: String?
    let calendarSourceTitle: String?
    let colorHex: String?

    var calendarDisplayName: String {
        let source = calendarSourceTitle ?? ""
        let cal = calendarTitle ?? ""
        if source.isEmpty { return cal }
        if cal.isEmpty { return source }
        return "\(source) → \(cal)"
    }
}

struct CreateEventsResult: Sendable {
    var created: [Date] = []
    var duplicates: [Date] = []
    var failed: [(date: Date, message: String)] = []
}

struct UndoResult: Sendable {
    var success: Bool
    var deletedCount: Int
    var alreadyDeletedCount: Int
}

enum CalendarError: LocalizedError, Sendable, Equatable {
    case defaultCalendarUnavailable
    case accessDenied
    case invalidIntervals

    var errorDescription: String? {
        switch self {
        case .defaultCalendarUnavailable:
            return NSLocalizedString("default_calendar_unavailable", comment: "")
        case .accessDenied:
            return NSLocalizedString("permission_required", comment: "")
        case .invalidIntervals:
            return "无效的复习间隔"
        }
    }
}
