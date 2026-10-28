import Foundation

@MainActor
struct DeletionPlan {
    struct Report: Equatable {
        var deleted: [String]
        var failed: [String]

        var isCompleteFailure: Bool { deleted.isEmpty && !failed.isEmpty }
        var isPartialFailure: Bool { !deleted.isEmpty && !failed.isEmpty }
        var isSuccess: Bool { failed.isEmpty }
    }

    private let calendar: CalendarService

    init(calendar: CalendarService) {
        self.calendar = calendar
    }

    func execute(ids: [String]) -> Report {
        var deleted: [String] = []
        var failed: [String] = []
        var seen = Set<String>()
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            if calendar.deleteEvent(id: id) {
                deleted.append(id)
            } else {
                failed.append(id)
            }
        }
        return Report(deleted: deleted, failed: failed)
    }
}
