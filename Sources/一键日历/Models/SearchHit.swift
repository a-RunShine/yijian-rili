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

    var isSeries: Bool {
        if case .series = kind { return true }
        return false
    }

    var needsSelectiveDelete: Bool { members.count > 1 }
}

enum RemoveEventsFromRecordedOutcome: Equatable {
    case noMatch
    case updated(id: UUID, remainingIdentifiers: [String])
    case discarded(id: UUID)
}
