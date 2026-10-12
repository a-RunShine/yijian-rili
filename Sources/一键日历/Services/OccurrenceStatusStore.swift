import Foundation

@MainActor
final class OccurrenceStatusStore {
    static let storageKey = "occurrenceStatusData"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func status(for eventId: String) -> OccurrenceStatus {
        load()[eventId] ?? .unmarked
    }

    func setStatus(_ status: OccurrenceStatus, for eventId: String) {
        var map = load()
        if status == .unmarked {
            map.removeValue(forKey: eventId)
        } else {
            map[eventId] = status
        }
        save(map)
    }

    func clear(ids: [String]) {
        guard !ids.isEmpty else { return }
        var map = load()
        var changed = false
        for id in ids {
            if map.removeValue(forKey: id) != nil {
                changed = true
            }
        }
        if changed {
            save(map)
        }
    }

    func markedEntries() -> [String: OccurrenceStatus] {
        load().filter { $0.value != .unmarked }
    }

    private func load() -> [String: OccurrenceStatus] {
        let raw = defaults.string(forKey: Self.storageKey) ?? "{}"
        guard let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: OccurrenceStatus].self, from: data) else {
            return [:]
        }
        return map
    }

    private func save(_ map: [String: OccurrenceStatus]) {
        if let data = try? JSONEncoder().encode(map),
           let string = String(data: data, encoding: .utf8) {
            defaults.set(string, forKey: Self.storageKey)
        }
    }
}
