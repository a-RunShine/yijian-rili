import Foundation

@MainActor
final class OccurrenceStatusStore {
    static let storageKey = "occurrenceStatusData"

    private let store: PersistentDictionary<OccurrenceStatus>

    var lastHealth: PayloadHealth { store.lastHealth }

    init(defaults: UserDefaults = .standard) {
        self.store = PersistentDictionary(key: Self.storageKey, defaults: defaults)
    }

    func status(for eventId: String) -> OccurrenceStatus {
        store.load()[eventId] ?? .unmarked
    }

    func setStatus(_ status: OccurrenceStatus, for eventId: String) {
        store.mutate { map in
            if status == .unmarked {
                map.removeValue(forKey: eventId)
            } else {
                map[eventId] = status
            }
        }
    }

    func clear(ids: [String]) {
        guard !ids.isEmpty else { return }
        store.mutate { map in
            for id in ids {
                map.removeValue(forKey: id)
            }
        }
    }

    func clearSeries(entryID: UUID) {
        let prefix = "series:\(entryID.uuidString):"
        store.mutate { map in
            for key in map.keys where key.hasPrefix(prefix) {
                map.removeValue(forKey: key)
            }
        }
    }

    func clearLegacy(ids: [String]) {
        guard !ids.isEmpty else { return }
        clear(ids: ids + ids.map { HistorySeriesLookup.legacyKey(for: $0) })
    }

    func markedEntries() -> [String: OccurrenceStatus] {
        store.load().filter { $0.value != .unmarked }
    }
}
