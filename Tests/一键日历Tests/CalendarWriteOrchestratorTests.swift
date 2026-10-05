import XCTest
@testable import 一键日历

final class WriteRulesTests: XCTestCase {
    func testReviewNoteKeyMatchesWindowsLiteral() {
        XCTAssertEqual(ReviewNoteKey.forIndex(0), "第1次复习")
        XCTAssertEqual(ReviewNoteKey.forIndex(2), "第3次复习")
        XCTAssertEqual(ReviewNoteKey.single, "")
    }

    func testNormalizeNotesStripsReminderLine() {
        XCTAssertEqual(NormalizeNotes.normalize(nil), "")
        XCTAssertEqual(NormalizeNotes.normalize(""), "")
        XCTAssertEqual(NormalizeNotes.normalize("第1次复习\n提醒建议：当天 09:00"), "第1次复习")
        XCTAssertEqual(NormalizeNotes.normalize("提醒建议：当天 09:00"), "")
        XCTAssertEqual(NormalizeNotes.normalize("  第2次复习  "), "第2次复习")
    }

    func testDuplicateMatchUsesNormalizedNotes() {
        let day = date(2026, 2, 3)
        let existing = [
            StoredCalendarEvent(
                id: "1",
                title: "Swift",
                day: day,
                rawNotes: "第1次复习\n提醒建议：当天 09:00"
            )
        ]
        XCTAssertTrue(
            DuplicateMatch.isDuplicate(title: "Swift", day: day, notesKey: "第1次复习", existing: existing)
        )
        XCTAssertFalse(
            DuplicateMatch.isDuplicate(title: "Swift", day: day, notesKey: "", existing: existing)
        )
    }

    func testIntervalRulesAlignWithWindows() {
        XCTAssertTrue(IntervalRules.validate([3, 7, 30]))
        XCTAssertFalse(IntervalRules.validate([30, 7, 3]))
        XCTAssertFalse(IntervalRules.validate([]))
        XCTAssertFalse(IntervalRules.validate([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}

@MainActor
final class CalendarWriteOrchestratorTests: XCTestCase {
    func testWriteReviewWithFakeStore() throws {
        let store = FakeCalendarEventStore()
        let base = date(2026, 1, 31)
        let outcome = try CalendarWriteOrchestrator.writeReview(
            title: "T",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: "cal",
            store: store
        )
        XCTAssertEqual(outcome.result.created.count, 3)
        XCTAssertTrue(outcome.result.duplicates.isEmpty)
        XCTAssertEqual(outcome.createdEventIds.count, 3)

        let again = try CalendarWriteOrchestrator.writeReview(
            title: "T",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: "cal",
            store: store
        )
        XCTAssertEqual(again.result.duplicates.count, 3)
        XCTAssertEqual(again.result.created.count, 3)
    }

    func testWriteSingleAndInvalidIntervals() throws {
        let store = FakeCalendarEventStore()
        let day = date(2026, 3, 1)
        let single = try CalendarWriteOrchestrator.writeSingle(
            title: "S",
            date: day,
            calendarId: "cal",
            store: store
        )
        XCTAssertEqual(single.result.created.count, 1)

        XCTAssertThrowsError(
            try CalendarWriteOrchestrator.writeReview(
                title: "T",
                baseDate: day,
                intervals: [30, 7, 3],
                calendarId: "cal",
                store: store
            )
        ) { error in
            XCTAssertEqual(error as? CalendarError, .invalidIntervals)
        }
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}

/// 假 store：供写入日历编排单测（不碰 EventKit）。
final class FakeCalendarEventStore: CalendarEventStore {
    private var items: [StoredCalendarEvent] = []
    private var seq = 0

    func events(calendarId: String, day: Date) throws -> [StoredCalendarEvent] {
        let start = Calendar.current.startOfDay(for: day)
        return items.filter {
            Calendar.current.isDate($0.day, inSameDayAs: start)
        }
    }

    func saveAllDay(calendarId: String, title: String, day: Date, notesKey: String) throws -> String {
        seq += 1
        let id = "fake-\(seq)"
        let raw: String
        if notesKey.isEmpty {
            raw = "提醒建议：当天 09:00"
        } else {
            raw = "\(notesKey)\n提醒建议：当天 09:00"
        }
        items.append(
            StoredCalendarEvent(
                id: id,
                title: title,
                day: Calendar.current.startOfDay(for: day),
                rawNotes: raw
            )
        )
        return id
    }
}
