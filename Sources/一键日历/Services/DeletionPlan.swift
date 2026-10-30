import Foundation

@MainActor
struct DeletionPlan {
    struct Report: Equatable {
        var removed: [RemovalTarget] = []
        var alreadyAbsent: [RemovalTarget] = []
        var refused: [(target: RemovalTarget, reason: EventRemovalRefusal)] = []

        var removedCount: Int { removed.count }

        var settledTargets: [RemovalTarget] { removed + alreadyAbsent }

        var settledStoredIds: [String] {
            settledTargets.compactMap(\.storedId)
        }

        var refusedStoredIds: [String] {
            refused.compactMap(\.target.storedId)
        }

        var refusalReasons: [EventRemovalRefusal] {
            refused.map(\.reason)
        }

        var isSuccess: Bool { refused.isEmpty }

        static func == (lhs: Report, rhs: Report) -> Bool {
            lhs.removed == rhs.removed
                && lhs.alreadyAbsent == rhs.alreadyAbsent
                && lhs.refused.map(\.target) == rhs.refused.map(\.target)
                && lhs.refused.map(\.reason) == rhs.refused.map(\.reason)
        }
    }

    private let calendar: CalendarService

    init(calendar: CalendarService) {
        self.calendar = calendar
    }

    func execute(requests: [EventRemovalRequest]) -> Report {
        var report = Report()
        var seen = Set<EventAddress>()
        for request in requests where !seen.contains(request.address) {
            seen.insert(request.address)
            let target = RemovalTarget(
                storedId: request.storedId,
                address: request.address
            )
            switch calendar.removeEvent(at: request.address, preferredId: request.storedId) {
            case .removed(let eventId):
                report.removed.append(
                    RemovalTarget(storedId: request.storedId ?? eventId, address: request.address)
                )
            case .alreadyAbsent:
                report.alreadyAbsent.append(target)
            case .refused(let reason):
                report.refused.append((target: target, reason: reason))
            }
        }
        return report
    }
}
