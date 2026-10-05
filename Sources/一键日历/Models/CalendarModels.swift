import Foundation

/// 日历访问权限（对齐 Windows `CalendarAccessStatus`）。
enum CalendarAccessStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
}

/// 日历账户来源（对齐 Windows `CalendarSourceKind`）。
enum CalendarSourceKind: Equatable, Sendable {
    case local
    case cloud
    case unknown
}

/// 可写日历摘要（日历 seam 对外类型，不含 EventKit）。
struct CalendarInfo: Identifiable, Hashable, Sendable {
    var id: String { identifier }

    let identifier: String
    let title: String
    let sourceTitle: String
    let sourceKind: CalendarSourceKind
    let allowsContentModifications: Bool
    /// `#RRGGBB`，可选；UI 用于色点
    let colorHex: String?

    var displayName: String { "\(sourceTitle) → \(title)" }
}

/// 日历事件摘要（日历 seam 对外类型，不含 EventKit）。
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

/// 写入日历结果（复习日程 / 单次日程）。
struct CreateEventsResult: Sendable {
    var created: [Date] = []
    var duplicates: [Date] = []
    var failed: [(date: Date, message: String)] = []
}

/// 撤销最近一次写入日历的结果。
struct UndoResult: Sendable {
    var success: Bool
    var deletedCount: Int
    var alreadyDeletedCount: Int
}

enum CalendarError: LocalizedError, Sendable, Equatable {
    case defaultCalendarUnavailable
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .defaultCalendarUnavailable:
            return NSLocalizedString("default_calendar_unavailable", comment: "")
        case .accessDenied:
            return NSLocalizedString("permission_required", comment: "")
        }
    }
}
