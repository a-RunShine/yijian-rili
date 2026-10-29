import Foundation

struct SearchHit: Identifiable, Equatable {
    enum Kind: Equatable {
        case single
        case series(historyEntryID: UUID)
    }

    let id: String
    let kind: Kind
    let title: String
    let members: [CalendarEventInfo]

    var representative: CalendarEventInfo { members[0] }

    var focusedEvent: CalendarEventInfo {
        members.first(where: { $0.id == id }) ?? representative
    }

    var isSeries: Bool {
        if case .series = kind { return true }
        return false
    }

    var spansMultipleOccurrences: Bool {
        if case .series = kind { return members.count > 1 }
        return false
    }

    var asksForDeleteScope: Bool { spansMultipleOccurrences }

    var needsSelectiveDelete: Bool { asksForDeleteScope }
}

enum RemoveEventsFromRecordedOutcome: Equatable {
    case noMatch
    case updated(id: UUID, remainingIdentifiers: [String])
    case discarded(id: UUID)
    case refusedNoAuthority
}
