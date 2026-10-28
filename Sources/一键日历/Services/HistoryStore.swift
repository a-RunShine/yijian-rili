import Foundation

final class HistoryStore {
    static let storageKey = "historyEntriesData"
    static let maxEntries = 20

    private let store: PersistentArray<HistoryEntry>
    private var pendingEvictions: [HistoryEntry] = []

    var lastHealth: PayloadHealth { store.lastHealth }

    init(defaults: UserDefaults = .standard) {
        self.store = PersistentArray(key: Self.storageKey, defaults: defaults)
    }

    func load() -> [HistoryEntry] {
        let entries = store.load()
        if entries.count <= Self.maxEntries { return entries }
        return Array(entries.prefix(Self.maxEntries))
    }

    func save(_ entries: [HistoryEntry]) {
        store.save(Array(entries.prefix(Self.maxEntries)))
    }

    @discardableResult
    func add(_ entry: HistoryEntry) -> HistoryEntry {
        pendingEvictions.removeAll()
        store.mutate { list in
            list.insert(entry, at: 0)
            if list.count > Self.maxEntries {
                pendingEvictions = Array(list.suffix(list.count - Self.maxEntries))
                list.removeLast(list.count - Self.maxEntries)
            }
        }
        return entry
    }

    func drainEvictedEntries() -> [HistoryEntry] {
        defer { pendingEvictions.removeAll() }
        return pendingEvictions
    }

    func remove(id: UUID) {
        store.mutate { list in
            list.removeAll { $0.id == id }
        }
    }

    func replace(_ entry: HistoryEntry) {
        store.mutate { list in
            guard let index = list.firstIndex(where: { $0.id == entry.id }) else { return }
            list[index] = entry
        }
    }

    func clear() {
        store.save([])
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
