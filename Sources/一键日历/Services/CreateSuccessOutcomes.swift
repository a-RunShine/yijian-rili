import Foundation

@MainActor
final class CreateSuccessOutcomes {
    private let history: HistoryStore
    private let weekly: WeeklyEntryAppending
    private let occurrenceStatuses: OccurrenceStatusStore?

    init(
        history: HistoryStore,
        weekly: WeeklyEntryAppending,
        occurrenceStatuses: OccurrenceStatusStore? = nil
    ) {
        self.history = history
        self.weekly = weekly
        self.occurrenceStatuses = occurrenceStatuses
    }

    func record(_ entry: HistoryEntry) {
        history.add(entry)
        weekly.appendWeeklyEntry(from: entry)
        for entry in history.drainEvictedEntries() {
            weekly.removeWeeklyEntries(id: entry.id)
            occurrenceStatuses?.clearSeries(entryID: entry.id)
            occurrenceStatuses?.clearLegacy(ids: entry.createdEventIdentifiers)
        }
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
        switch removeEventsFromRecorded(ids: [id], reason: .userDeletedOccurrence) {
        case .discarded(let entryID):
            return entryID
        case .updated, .noMatch, .refusedNoAuthority:
            return nil
        }
    }

    @discardableResult
    func removeEventsFromRecorded(
        ids: [String],
        reason: RecordedPruneReason
    ) -> RemoveEventsFromRecordedOutcome {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return .noMatch }
        guard let entry = history.load().first(where: {
            $0.createdEventIdentifiers.contains(where: idSet.contains)
        }) else {
            return .noMatch
        }
        let slots = entry.createdEventIdentifiers.map { idSet.contains($0) ? "" : $0 }
        let survivors = slots.filter { !$0.isEmpty }
        if survivors.isEmpty {
            discardRecorded(id: entry.id)
            return .discarded(id: entry.id)
        }
        history.replace(entry.withCreatedEventIdentifiers(slots))
        return .updated(id: entry.id, remainingIdentifiers: survivors)
    }

    func replaceCreatedEventIdentifiers(id: UUID, identifiers: [String]) {
        guard let existing = history.load().first(where: { $0.id == id }) else { return }
        history.replace(existing.withCreatedEventIdentifiers(identifiers))
    }

    func updateSharedDetail(id: UUID, sharedDetail: String?) {
        guard let existing = history.load().first(where: { $0.id == id }) else { return }
        history.replace(existing.withSharedDetail(sharedDetail))
    }

    func updateTitle(id: UUID, title: String) {
        guard let existing = history.load().first(where: { $0.id == id }) else { return }
        history.replace(existing.withTitle(title))
        weekly.updateWeeklyEntryTitle(id: id, title: title)
    }

    func recordedEntries() -> [HistoryEntry] {
        history.load()
    }

    func todayCreatedEntries(now: Date = Date(), calendar: Calendar = .current) -> [HistoryEntry] {
        history.created(on: now, calendar: calendar)
    }
}
