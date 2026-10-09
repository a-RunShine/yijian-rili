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

    @discardableResult
    func discardRecordedContainingEvent(id: String) -> UUID? {
        switch removeEventsFromRecorded(ids: [id]) {
        case .discarded(let entryID):
            return entryID
        case .updated, .noMatch:
            return nil
        }
    }

    @discardableResult
    func removeEventsFromRecorded(ids: [String]) -> RemoveEventsFromRecordedOutcome {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return .noMatch }
        guard let entry = history.load().first(where: {
            $0.createdEventIdentifiers.contains(where: idSet.contains)
        }) else {
            return .noMatch
        }
        let remaining = entry.createdEventIdentifiers.filter { !idSet.contains($0) }
        if remaining.isEmpty {
            discardRecorded(id: entry.id)
            return .discarded(id: entry.id)
        }
        history.replace(entry.withCreatedEventIdentifiers(remaining))
        return .updated(id: entry.id, remainingIdentifiers: remaining)
    }

    func updateSharedDetail(id: UUID, sharedDetail: String?) {
        guard let existing = history.load().first(where: { $0.id == id }) else { return }
        history.replace(existing.withSharedDetail(sharedDetail))
    }

    func todayCreatedEntries(now: Date = Date(), calendar: Calendar = .current) -> [HistoryEntry] {
        history.created(on: now, calendar: calendar)
    }
}
