import Foundation
import SwiftUI

@MainActor
final class WeeklyReviewViewModel: ObservableObject, WeeklyEntryAppending {

    static let weeklyEntriesKey = "weeklyEntriesData"
    static let weeklyReviewStateKey = "weeklyReviewStateData"
    static let weeklyNotesKey = "weeklyNotesData"
    static let historyMigrationKey = "weeklyEntriesHistoryMigrationDone"
    static let weekendMigrationKey = "weeklyEntriesWeekendMigrationDone"
    static var legacyHistoryEntriesKey: String { HistoryStore.storageKey }

    @Published var currentWeekStart: Date

    @Published var noteDraft: String = ""

    let themeProvider: ThemeProvider

    @Published private(set) var revision: Int = 0

    private let defaults: UserDefaults
    private var weeklyEntriesJSON: String {
        get { defaults.string(forKey: WeeklyReviewViewModel.weeklyEntriesKey) ?? "[]" }
        set { defaults.set(newValue, forKey: WeeklyReviewViewModel.weeklyEntriesKey) }
    }
    private var reviewedJSON: String {
        get { defaults.string(forKey: WeeklyReviewViewModel.weeklyReviewStateKey) ?? "[]" }
        set { defaults.set(newValue, forKey: WeeklyReviewViewModel.weeklyReviewStateKey) }
    }
    private var notesJSON: String {
        get { defaults.string(forKey: WeeklyReviewViewModel.weeklyNotesKey) ?? "{\"byWeek\":{}}" }
        set { defaults.set(newValue, forKey: WeeklyReviewViewModel.weeklyNotesKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentWeekStart = WeekCalculator.weekStart(for: Date())
        self.themeProvider = ThemeProvider()
        performHistoryMigrationIfNeeded()
        performWeekendMigrationIfNeeded()
        reloadDraftForCurrentWeek()
    }

    var currentWeekEnd: Date {
        WeekCalculator.weekEnd(for: currentWeekStart)
    }

    var currentWeekKey: String {
        WeekCalculator.weekKey(for: currentWeekStart)
    }

    var weeklyEntries: [WeeklyEntry] {
        _ = revision
        guard let data = weeklyEntriesJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([WeeklyEntry].self, from: data) else {
            return []
        }
        return entries
    }

    var reviewedIds: Set<UUID> {
        _ = revision
        guard let data = reviewedJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    var currentWeekNote: String {
        _ = revision
        let notes = decodeNotes()
        return notes.byWeek[currentWeekKey] ?? ""
    }

    var entriesInCurrentWeek: [WeeklyEntry] {
        let start = currentWeekStart
        let end = currentWeekEnd
        return weeklyEntries
            .filter { $0.creationDate >= start && $0.creationDate <= end }
            .sorted { $0.creationDate > $1.creationDate }
    }

    var entriesGroupedByCreationDate: [(date: Date, entries: [WeeklyEntry])] {
        let entries = entriesInCurrentWeek
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            cal.startOfDay(for: entry.creationDate)
        }
        return grouped
            .map { (date: $0.key, entries: $0.value.sorted { $0.creationDate > $1.creationDate }) }
            .sorted { $0.date > $1.date }
    }

    var realEntriesInCurrentWeek: [WeeklyEntry] {
        entriesInCurrentWeek.filter { !$0.isPreOccupiedNextWeek }
    }

    var reviewedCount: Int {
        let entries = realEntriesInCurrentWeek
        let reviewed = reviewedIds
        return entries.filter { reviewed.contains($0.id) }.count
    }

    var totalCount: Int {
        realEntriesInCurrentWeek.count
    }

    var canGoToNextWeek: Bool {
        let thisMonday = WeekCalculator.weekStart(for: Date())
        return currentWeekStart < thisMonday
    }

    func goToPreviousWeek() {
        commitNoteDraft()
        currentWeekStart = WeekCalculator.addingWeeks(-1, to: currentWeekStart)
        reloadDraftForCurrentWeek()
        revision &+= 1
    }

    func goToNextWeek() {
        guard canGoToNextWeek else { return }
        commitNoteDraft()
        currentWeekStart = WeekCalculator.addingWeeks(1, to: currentWeekStart)
        reloadDraftForCurrentWeek()
        revision &+= 1
    }

    func jumpToCurrentWeek() {
        commitNoteDraft()
        currentWeekStart = WeekCalculator.weekStart(for: Date())
        reloadDraftForCurrentWeek()
        revision &+= 1
    }

    func commitNoteDraft() {
        var notes = decodeNotes()
        let key = currentWeekKey
        let trimmed = noteDraft
        if notes.byWeek[key] != trimmed {
            notes.byWeek[key] = trimmed
            writeNotes(notes)
            revision &+= 1
        }
    }

    func updateNote(_ text: String) {
        noteDraft = text
        var notes = decodeNotes()
        notes.byWeek[currentWeekKey] = text
        writeNotes(notes)
        revision &+= 1
    }

    private func reloadDraftForCurrentWeek() {
        noteDraft = currentWeekNote
    }

    func isReviewed(_ id: UUID) -> Bool {
        reviewedIds.contains(id)
    }

    func toggleReviewed(_ id: UUID) {
        var set = reviewedIds
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        persistReviewed(set)
        revision &+= 1
    }

    private func persistReviewed(_ set: Set<UUID>) {
        let array = Array(set)
        if let data = try? JSONEncoder().encode(array),
           let string = String(data: data, encoding: .utf8) {
            reviewedJSON = string
        }
    }

    func appendWeeklyEntry(from historyEntry: HistoryEntry) {
        var entries = weeklyEntries
        entries.removeAll { $0.id == historyEntry.id }

        let primary = WeeklyEntry(
            id: historyEntry.id,
            title: historyEntry.title,
            baseDate: historyEntry.baseDate,
            scheduleType: historyEntry.type,
            creationDate: historyEntry.creationDate,
            isPreOccupiedNextWeek: false
        )
        entries.append(primary)

        if historyEntry.type == .review,
           WeekCalculator.isWeekend(historyEntry.creationDate) {
            let nextMonday = WeekCalculator.nextWeekMonday(after: historyEntry.creationDate)
            if !entries.contains(where: { $0.id == historyEntry.id && $0.creationDate == nextMonday }) {
                let placeholder = WeeklyEntry(
                    id: historyEntry.id,
                    title: historyEntry.title,
                    baseDate: historyEntry.baseDate,
                    scheduleType: historyEntry.type,
                    creationDate: nextMonday,
                    isPreOccupiedNextWeek: true
                )
                entries.append(placeholder)
            }
        }

        persistWeeklyEntries(entries)
        revision &+= 1
    }

    func removeWeeklyEntries(id: UUID) {
        var entries = weeklyEntries
        let before = entries.count
        entries.removeAll { $0.id == id }
        guard entries.count != before else { return }
        persistWeeklyEntries(entries)
        revision &+= 1
    }

    func persistWeeklyEntries(_ entries: [WeeklyEntry]) {
        if let data = try? JSONEncoder().encode(entries),
           let string = String(data: data, encoding: .utf8) {
            weeklyEntriesJSON = string
        }
    }

    func performHistoryMigrationIfNeeded() {
        guard !defaults.bool(forKey: WeeklyReviewViewModel.historyMigrationKey) else {
            return
        }

        let legacyRaw = defaults.string(forKey: WeeklyReviewViewModel.legacyHistoryEntriesKey) ?? ""
        let legacyEntries: [HistoryEntry]
        if legacyRaw.isEmpty {
            legacyEntries = []
        } else if let data = legacyRaw.data(using: .utf8) {
            legacyEntries = (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
        } else {
            legacyEntries = []
        }

        let existingEntries = weeklyEntries
        let existingIds = Set(existingEntries.map { $0.id })
        let toMigrate = legacyEntries.filter { !existingIds.contains($0.id) }

        if !toMigrate.isEmpty {
            let converted: [WeeklyEntry] = toMigrate.map { history in
                WeeklyEntry(
                    id: history.id,
                    title: history.title,
                    baseDate: history.baseDate,
                    scheduleType: history.type,
                    creationDate: history.creationDate
                )
            }
            let merged = existingEntries + converted
            persistWeeklyEntries(merged)
            revision &+= 1
        }

        defaults.set(true, forKey: WeeklyReviewViewModel.historyMigrationKey)
    }

    func performWeekendMigrationIfNeeded() {
        guard !defaults.bool(forKey: WeeklyReviewViewModel.weekendMigrationKey) else {
            return
        }

        let entries = weeklyEntries
        guard !entries.isEmpty else {
            defaults.set(true, forKey: WeeklyReviewViewModel.weekendMigrationKey)
            return
        }

        var changed = false
        var result: [WeeklyEntry] = entries

        for entry in entries where !entry.isPreOccupiedNextWeek {
            guard entry.scheduleType == .review,
                  WeekCalculator.isWeekend(entry.creationDate) else {
                continue
            }
            let nextMonday = WeekCalculator.nextWeekMonday(after: entry.creationDate)
            let exists = entries.contains(where: { existing in
                existing.id == entry.id &&
                existing.creationDate == nextMonday &&
                existing.isPreOccupiedNextWeek
            })
            if exists { continue }

            let placeholder = WeeklyEntry(
                id: entry.id,
                title: entry.title,
                baseDate: entry.baseDate,
                scheduleType: entry.scheduleType,
                creationDate: nextMonday,
                isPreOccupiedNextWeek: true
            )
            result.append(placeholder)
            changed = true
        }

        if changed {
            persistWeeklyEntries(result)
            revision &+= 1
        }

        defaults.set(true, forKey: WeeklyReviewViewModel.weekendMigrationKey)
    }

    private func decodeNotes() -> WeeklyNotes {
        guard let data = notesJSON.data(using: .utf8) else { return WeeklyNotes(byWeek: [:]) }
        return (try? JSONDecoder().decode(WeeklyNotes.self, from: data)) ?? WeeklyNotes(byWeek: [:])
    }

    private func writeNotes(_ notes: WeeklyNotes) {
        if let data = try? JSONEncoder().encode(notes),
           let string = String(data: data, encoding: .utf8) {
            notesJSON = string
        }
    }

    func resetForTest() {
        weeklyEntriesJSON = "[]"
        reviewedJSON = "[]"
        notesJSON = "{\"byWeek\":{}}"
        noteDraft = ""
        currentWeekStart = WeekCalculator.weekStart(for: Date())
        defaults.removeObject(forKey: WeeklyReviewViewModel.historyMigrationKey)
        defaults.removeObject(forKey: WeeklyReviewViewModel.weekendMigrationKey)
        revision &+= 1
    }
}

struct WeeklyNotes: Codable, Equatable {
    var byWeek: [String: String]

    init(byWeek: [String: String] = [:]) {
        self.byWeek = byWeek
    }
}

@MainActor
final class ThemeProvider: ObservableObject {
    @Published var theme: Theme = {
        let raw = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: raw) ?? .light
    }()

    init() {
    }
}
