import Foundation

struct CalendarLookupAuthority: Equatable {
    private init() {}

    static func verified(_ status: CalendarAccessStatus) -> CalendarLookupAuthority? {
        status == .fullAccess ? CalendarLookupAuthority() : nil
    }
}

enum RecordedPruneReason: Equatable {
    case calendarConfirmedMissing(CalendarLookupAuthority)
    case userDeletedOccurrence
}

enum ReconcileOutcome: Equatable {
    case skippedNoAccess
    case unchanged
    case pruned(count: Int)
}
