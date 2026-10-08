import Foundation

@MainActor
final class CreateSuccessOutcomes {
    private let history: HistoryStore
    private let weekly: WeeklyEntryAppending

    init(history: HistoryStore, weekly: WeeklyEntryAppending) {
        self.history = history
        self.weekly = weekly
    }

    func record(_ entry: HistoryEntry) {
        history.add(entry)
        weekly.appendWeeklyEntry(from: entry)
    }

    func clearHistory() {
        history.clear()
    }

    func removeHistory(id: UUID) {
        history.remove(id: id)
    }

    func discardRecorded(id: UUID) {
        history.remove(id: id)
        weekly.removeWeeklyEntries(id: id)
    }

    func updateSharedDetail(id: UUID, sharedDetail: String?) {
        guard let existing = history.load().first(where: { $0.id == id }) else { return }
        history.replace(existing.withSharedDetail(sharedDetail))
    }

    func todayCreatedEntries(now: Date = Date(), calendar: Calendar = .current) -> [HistoryEntry] {
        history.created(on: now, calendar: calendar)
    }
}
