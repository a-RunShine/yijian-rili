import Foundation

@MainActor
protocol WeeklyEntryAppending: AnyObject {
    func appendWeeklyEntry(from historyEntry: HistoryEntry)
    func removeWeeklyEntries(id: UUID)
}
