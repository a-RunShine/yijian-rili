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

    func testNotesDetailExtractStripsReviewKeyAndReminder() {
        XCTAssertEqual(NotesDetail.extract(nil), "")
        XCTAssertEqual(NotesDetail.extract(""), "")
        XCTAssertEqual(
            NotesDetail.extract("第1次复习\n提醒建议：当天 09:00"),
            ""
        )
        XCTAssertEqual(
            NotesDetail.extract("第2次复习\n提醒建议：当天 09:00\n课堂补充"),
            "课堂补充"
        )
        XCTAssertEqual(
            NotesDetail.extract("提醒建议：当天 09:00\n单次备注"),
            "单次备注"
        )
        XCTAssertEqual(
            NotesDetail.extract("提醒建议：当天 09:00"),
            ""
        )
        XCTAssertEqual(
            NotesDetail.extract("第3次复习\n提醒建议：当天 09:00\n第一行\n第二行"),
            "第一行\n第二行"
        )
        XCTAssertEqual(
            NotesDetail.extract("第1次复习\n提醒建议：当天 09:00\n  两端空白  "),
            "两端空白"
        )
        XCTAssertEqual(
            NotesDetail.extract(ReviewNotes.compose(key: "第1次复习", detail: "共享详情")),
            "共享详情"
        )
        XCTAssertEqual(
            NotesDetail.extract(ReviewNotes.compose(key: "", detail: "仅单次")),
            "仅单次"
        )
        XCTAssertEqual(
            NotesDetail.extract(ReviewNotes.compose(key: "第2次复习", detail: nil)),
            ""
        )
    }

    func testReviewNotesComposeKeepsKeyFirstLine() {
        XCTAssertEqual(
            ReviewNotes.compose(key: "第1次复习", detail: nil),
            "第1次复习\n提醒建议：当天 09:00"
        )
        XCTAssertEqual(
            ReviewNotes.compose(key: "第1次复习", detail: "  课堂补充  "),
            "第1次复习\n提醒建议：当天 09:00\n课堂补充"
        )
        XCTAssertEqual(
            ReviewNotes.compose(key: "", detail: nil),
            "提醒建议：当天 09:00"
        )
        XCTAssertEqual(
            ReviewNotes.compose(key: "", detail: "单次备注"),
            "提醒建议：当天 09:00\n单次备注"
        )
        XCTAssertEqual(
            ReviewNotes.compose(key: "第2次复习", detail: "  "),
            "第2次复习\n提醒建议：当天 09:00"
        )
        XCTAssertEqual(
            NormalizeNotes.normalize(ReviewNotes.compose(key: "第1次复习", detail: "extra")),
            "第1次复习"
        )
        XCTAssertEqual(
            NormalizeNotes.normalize(ReviewNotes.compose(key: "", detail: "extra")),
            ""
        )
    }

    func testReviewNotesReplacingDetailPreservesKeyAndReminder() {
        let original = ReviewNotes.compose(key: "第2次复习", detail: "旧详情")
        XCTAssertEqual(
            ReviewNotes.replacingDetail(in: original, detail: "新详情"),
            ReviewNotes.compose(key: "第2次复习", detail: "新详情")
        )
        let single = ReviewNotes.compose(key: "", detail: "单次旧")
        XCTAssertEqual(
            ReviewNotes.replacingDetail(in: single, detail: "单次新"),
            ReviewNotes.compose(key: "", detail: "单次新")
        )
        XCTAssertEqual(
            ReviewNotes.replacingDetail(in: original, detail: "  "),
            ReviewNotes.compose(key: "第2次复习", detail: nil)
        )
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

    func testWriteReviewWithDetailComposesSharedNotesBlob() throws {
        let store = FakeCalendarEventStore()
        let base = date(2026, 1, 31)
        let outcome = try CalendarWriteOrchestrator.writeReview(
            title: "T",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: "cal",
            store: store,
            detail: "共享详情"
        )
        XCTAssertEqual(outcome.result.created.count, 3)
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(
            store.items[0].rawNotes,
            ReviewNotes.compose(key: "第1次复习", detail: "共享详情")
        )
        XCTAssertEqual(
            store.items[2].rawNotes,
            ReviewNotes.compose(key: "第3次复习", detail: "共享详情")
        )
        XCTAssertEqual(NormalizeNotes.normalize(store.items[0].rawNotes), "第1次复习")

        let again = try CalendarWriteOrchestrator.writeReview(
            title: "T",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: "cal",
            store: store,
            detail: "另一详情"
        )
        XCTAssertEqual(again.result.duplicates.count, 3)
    }

    func testRewriteSharedDetailUpdatesAndCountsMissing() {
        var notesById = [
            "a": ReviewNotes.compose(key: "第1次复习", detail: "旧"),
            "b": ReviewNotes.compose(key: "第2次复习", detail: "旧")
        ]
        let counts = CalendarWriteOrchestrator.rewriteSharedDetail(
            identifiers: ["a", "missing", "b"],
            detail: "新",
            eventNotes: { notesById[$0] },
            updateEventNotes: { id, notes in
                guard notesById[id] != nil else { return false }
                notesById[id] = notes
                return true
            }
        )
        XCTAssertEqual(counts.updated, 2)
        XCTAssertEqual(counts.missing, 1)
        XCTAssertEqual(notesById["a"], ReviewNotes.compose(key: "第1次复习", detail: "新"))
        XCTAssertEqual(notesById["b"], ReviewNotes.compose(key: "第2次复习", detail: "新"))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}

@MainActor
final class FakeCalendarEventStore: CalendarEventStore {
    private(set) var items: [StoredCalendarEvent] = []
    private var seq = 0

    func events(calendarId: String, day: Date) throws -> [StoredCalendarEvent] {
        let start = Calendar.current.startOfDay(for: day)
        return items.filter {
            Calendar.current.isDate($0.day, inSameDayAs: start)
        }
    }

    func saveAllDay(calendarId: String, title: String, day: Date, notes: String) throws -> String {
        seq += 1
        let id = "fake-\(seq)"
        items.append(
            StoredCalendarEvent(
                id: id,
                title: title,
                day: Calendar.current.startOfDay(for: day),
                rawNotes: notes
            )
        )
        return id
    }
}
