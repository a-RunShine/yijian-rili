import Foundation

enum IntervalDraftFailure: Error, Equatable {
    case empty
    case tooMany
    case invalidAt(Int)
    case notIncreasingAt(Int)
}

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

    static func parseDraft(_ draft: [String]) -> Result<[Int], IntervalDraftFailure> {
        guard !draft.isEmpty else { return .failure(.empty) }
        guard draft.count <= maxIntervalCount else { return .failure(.tooMany) }

        var intervals: [Int] = []
        intervals.reserveCapacity(draft.count)
        for (index, raw) in draft.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard let value = Int(trimmed),
                  value >= minIntervalDays,
                  value <= maxIntervalDays else {
                return .failure(.invalidAt(index + 1))
            }
            intervals.append(value)
        }

        for i in 1..<intervals.count {
            if intervals[i] <= intervals[i - 1] {
                return .failure(.notIncreasingAt(i + 1))
            }
        }

        return .success(intervals)
    }
}

enum ReviewNoteKey {
    static func forIndex(_ zeroBasedIndex: Int) -> String {
        "第\(zeroBasedIndex + 1)次复习"
    }

    static let single = ""
}

enum ReviewNotes {
    static let reminderLine = "提醒建议：当天 09:00"

    static func compose(key: String, detail: String?) -> String {
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var lines: [String] = []
        if !key.isEmpty {
            lines.append(key)
        }
        lines.append(reminderLine)
        if !trimmedDetail.isEmpty {
            lines.append(trimmedDetail)
        }
        return lines.joined(separator: "\n")
    }

    static func replacingDetail(in notes: String, detail: String?) -> String {
        compose(key: NormalizeNotes.normalize(notes), detail: detail)
    }
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
