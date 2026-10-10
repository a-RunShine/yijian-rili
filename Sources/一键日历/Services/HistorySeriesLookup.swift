import Foundation

enum HistorySeriesLookup {
    static func entry(containingEventId eventId: String, in history: [HistoryEntry]) -> HistoryEntry? {
        history.first { !$0.createdEventIdentifiers.isEmpty && $0.createdEventIdentifiers.contains(eventId) }
    }
}
