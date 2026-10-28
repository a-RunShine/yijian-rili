import Foundation

enum PayloadHealth: Equatable {
    case empty
    case intact
    case partiallyRecovered(dropped: Int)
    case restoredFromBackup
    case unreadable

    var isDamaged: Bool {
        switch self {
        case .empty, .intact:
            return false
        case .partiallyRecovered, .restoredFromBackup, .unreadable:
            return true
        }
    }
}

enum PersistentPayload {
    static let backupSuffix = ".backup"
    static let damagedSuffix = ".damaged"

    static func backupKey(_ key: String) -> String {
        key + backupSuffix
    }

    static func damagedKey(_ key: String) -> String {
        key + damagedSuffix
    }

    static func stashDamage(raw: String, key: String, defaults: UserDefaults) {
        guard !raw.isEmpty else { return }
        defaults.set(raw, forKey: damagedKey(key))
    }

    static func salvageArray<T: Decodable>(_ type: T.Type, raw: String) -> (values: [T], dropped: Int)? {
        guard let data = raw.data(using: .utf8) else { return nil }
        if let direct = try? JSONDecoder().decode([T].self, from: data) {
            return (direct, 0)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let elements = object as? [Any] else {
            return nil
        }
        var values: [T] = []
        var dropped = 0
        for element in elements {
            guard let elementData = try? JSONSerialization.data(
                withJSONObject: element,
                options: [.fragmentsAllowed]
            ),
                let value = try? JSONDecoder().decode(T.self, from: elementData) else {
                dropped += 1
                continue
            }
            values.append(value)
        }
        return (values, dropped)
    }

    static func salvageDictionary<T: Decodable>(_ type: T.Type, raw: String) -> (values: [String: T], dropped: Int)? {
        guard let data = raw.data(using: .utf8) else { return nil }
        if let direct = try? JSONDecoder().decode([String: T].self, from: data) {
            return (direct, 0)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let elements = object as? [String: Any] else {
            return nil
        }
        var values: [String: T] = [:]
        var dropped = 0
        for (key, element) in elements {
            guard let elementData = try? JSONSerialization.data(
                withJSONObject: element,
                options: [.fragmentsAllowed]
            ),
                let value = try? JSONDecoder().decode(T.self, from: elementData) else {
                dropped += 1
                continue
            }
            values[key] = value
        }
        return (values, dropped)
    }

    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearStaleDamage(key: String, defaults: UserDefaults) {
        defaults.removeObject(forKey: damagedKey(key))
    }
}

final class PersistentValue<T: Codable> {
    private let key: String
    private let defaults: UserDefaults

    private(set) var lastHealth: PayloadHealth = .empty

    init(key: String, defaults: UserDefaults) {
        self.key = key
        self.defaults = defaults
    }

    func load(fallback: T) -> T {
        let raw = defaults.string(forKey: key) ?? ""
        guard !raw.isEmpty else {
            lastHealth = .empty
            return fallback
        }
        if let data = raw.data(using: .utf8),
           let value = try? JSONDecoder().decode(T.self, from: data) {
            lastHealth = .intact
            return value
        }
        let backupRaw = defaults.string(forKey: PersistentPayload.backupKey(key)) ?? ""
        if !backupRaw.isEmpty,
           let data = backupRaw.data(using: .utf8),
           let value = try? JSONDecoder().decode(T.self, from: data) {
            lastHealth = .restoredFromBackup
            return value
        }
        lastHealth = .unreadable
        return fallback
    }

    func save(_ value: T) {
        guard let text = PersistentPayload.encode(value) else { return }
        defaults.set(text, forKey: PersistentPayload.backupKey(key))
        defaults.set(text, forKey: key)
    }

    func mutate(_ fallback: T, _ body: (inout T) -> Void) {
        var value = load(fallback: fallback)
        if lastHealth.isDamaged {
            PersistentPayload.stashDamage(
                raw: defaults.string(forKey: key) ?? "",
                key: key,
                defaults: defaults
            )
        }
        body(&value)
        save(value)
    }
}

final class PersistentArray<T: Codable> {
    private let key: String
    private let defaults: UserDefaults

    private(set) var lastHealth: PayloadHealth = .empty

    init(key: String, defaults: UserDefaults) {
        self.key = key
        self.defaults = defaults
    }

    func load() -> [T] {
        let raw = defaults.string(forKey: key) ?? ""
        guard !raw.isEmpty else {
            lastHealth = .empty
            return []
        }
        let salvaged = PersistentPayload.salvageArray(T.self, raw: raw)
        if let salvaged, salvaged.dropped == 0 {
            lastHealth = .intact
            return salvaged.values
        }
        let backupRaw = defaults.string(forKey: PersistentPayload.backupKey(key)) ?? ""
        if !backupRaw.isEmpty,
           let restored = PersistentPayload.salvageArray(T.self, raw: backupRaw),
           restored.dropped == 0,
           !restored.values.isEmpty {
            lastHealth = .restoredFromBackup
            return restored.values
        }
        if let salvaged, !salvaged.values.isEmpty {
            lastHealth = .partiallyRecovered(dropped: salvaged.dropped)
            return salvaged.values
        }
        lastHealth = .unreadable
        return []
    }

    func save(_ values: [T]) {
        guard let text = PersistentPayload.encode(values) else { return }
        defaults.set(text, forKey: PersistentPayload.backupKey(key))
        defaults.set(text, forKey: key)
    }

    @discardableResult
    func mutate(_ body: (inout [T]) -> Void) -> [T] {
        let current = load()
        if lastHealth.isDamaged {
            PersistentPayload.stashDamage(
                raw: defaults.string(forKey: key) ?? "",
                key: key,
                defaults: defaults
            )
        }
        var values = current
        body(&values)
        save(values)
        return values
    }
}

final class PersistentDictionary<T: Codable> {
    private let key: String
    private let defaults: UserDefaults

    private(set) var lastHealth: PayloadHealth = .empty

    init(key: String, defaults: UserDefaults) {
        self.key = key
        self.defaults = defaults
    }

    func load() -> [String: T] {
        let raw = defaults.string(forKey: key) ?? ""
        guard !raw.isEmpty else {
            lastHealth = .empty
            return [:]
        }
        let salvaged = PersistentPayload.salvageDictionary(T.self, raw: raw)
        if let salvaged, salvaged.dropped == 0 {
            lastHealth = .intact
            return salvaged.values
        }
        let backupRaw = defaults.string(forKey: PersistentPayload.backupKey(key)) ?? ""
        if !backupRaw.isEmpty,
           let restored = PersistentPayload.salvageDictionary(T.self, raw: backupRaw),
           restored.dropped == 0,
           !restored.values.isEmpty {
            lastHealth = .restoredFromBackup
            return restored.values
        }
        if let salvaged, !salvaged.values.isEmpty {
            lastHealth = .partiallyRecovered(dropped: salvaged.dropped)
            return salvaged.values
        }
        lastHealth = .unreadable
        return [:]
    }

    func save(_ values: [String: T]) {
        guard let text = PersistentPayload.encode(values) else { return }
        defaults.set(text, forKey: PersistentPayload.backupKey(key))
        defaults.set(text, forKey: key)
    }

    @discardableResult
    func mutate(_ body: (inout [String: T]) -> Void) -> [String: T] {
        let current = load()
        if lastHealth.isDamaged {
            PersistentPayload.stashDamage(
                raw: defaults.string(forKey: key) ?? "",
                key: key,
                defaults: defaults
            )
        }
        var values = current
        body(&values)
        save(values)
        return values
    }
}
