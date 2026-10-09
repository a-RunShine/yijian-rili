import Foundation

final class HistoryStore {
    static let storageKey = "historyEntriesData"
    static let maxEntries = 20

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [HistoryEntry] {
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        if entries.count <= Self.maxEntries { return entries }
        return Array(entries.prefix(Self.maxEntries))
    }

    func save(_ entries: [HistoryEntry]) {
        let capped = Array(entries.prefix(Self.maxEntries))
        if let data = try? JSONEncoder().encode(capped),
           let string = String(data: data, encoding: .utf8) {
            defaults.set(string, forKey: Self.storageKey)
        }
    }

    @discardableResult
    func add(_ entry: HistoryEntry) -> HistoryEntry {
        var list = load()
        list.insert(entry, at: 0)
        save(list)
        return entry
    }

    func remove(id: UUID) {
        save(load().filter { $0.id != id })
    }

    func replace(_ entry: HistoryEntry) {
        var list = load()
        guard let index = list.firstIndex(where: { $0.id == entry.id }) else { return }
        list[index] = entry
        save(list)
    }

    func clear() {
        save([])
    }

    func filter(_ query: String) -> [HistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return load() }
        return load().filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    func created(on day: Date, calendar: Calendar = .current) -> [HistoryEntry] {
        load().filter { calendar.isDate($0.creationDate, inSameDayAs: day) }
    }
}
