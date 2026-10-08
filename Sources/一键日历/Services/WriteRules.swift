import Foundation

enum IntervalRules {
    static let defaultIntervals = [3, 7, 30]
    static let minIntervalDays = 1
    static let maxIntervalDays = 365
    static let maxIntervalCount = 10

    static func validate(_ intervals: [Int]) -> Bool {
        guard !intervals.isEmpty else { return false }
        guard intervals.count <= maxIntervalCount else { return false }
        guard intervals.allSatisfy({ $0 >= minIntervalDays && $0 <= maxIntervalDays }) else { return false }
        for i in 1..<intervals.count {
            if intervals[i] <= intervals[i - 1] { return false }
        }
        return true
    }
}

enum ReviewNoteKey {
    static func forIndex(_ zeroBasedIndex: Int) -> String {
        "第\(zeroBasedIndex + 1)次复习"
    }

    static let single = ""
}

enum NormalizeNotes {
    static func normalize(_ details: String?) -> String {
        guard let details, !details.isEmpty else { return "" }
        let first = details.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if first.hasPrefix("提醒建议") { return "" }
        return first
    }
}

enum DuplicateMatch {
    static func isDuplicate(
        title: String,
        day: Date,
        notesKey: String,
        existing: [StoredCalendarEvent]
    ) -> Bool {
        let dayStart = Calendar.current.startOfDay(for: day)
        let wantKey = NormalizeNotes.normalize(notesKey)
        return existing.contains { event in
            Calendar.current.isDate(event.day, inSameDayAs: dayStart)
                && event.title == title
                && NormalizeNotes.normalize(event.rawNotes) == wantKey
        }
    }
}
