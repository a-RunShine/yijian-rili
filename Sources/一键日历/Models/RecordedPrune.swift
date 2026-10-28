import Foundation

struct CalendarLookupAuthority: Equatable {
    private init() {}

    static func verified(_ status: CalendarAccessStatus) -> CalendarLookupAuthority? {
        status == .fullAccess ? CalendarLookupAuthority() : nil
    }
}

enum RecordedPruneReason: Equatable {
    case userDeletedOccurrence
}

enum ReconcileOutcome: Equatable {
    case skippedNoAccess
    case unchanged
    case unmatched(count: Int)
}
