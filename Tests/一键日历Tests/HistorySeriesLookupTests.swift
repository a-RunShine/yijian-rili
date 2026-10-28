import XCTest
@testable import 一键日历

final class HistorySeriesLookupTests: XCTestCase {
    func testFindsReviewSeriesContainingEventId() {
        let entry = HistoryEntry(
            title: "复习A",
            baseDate: date(2026, 1, 1),
            reviewDates: [date(2026, 1, 4), date(2026, 1, 8)],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: ["e1", "e2", "e3"],
            sharedDetail: "课堂要点"
        )
        let other = HistoryEntry(
            title: "复习B",
            baseDate: date(2026, 2, 1),
            reviewDates: [date(2026, 2, 4)],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: ["x1"],
            sharedDetail: nil
        )
        let found = HistorySeriesLookup.entry(containingEventId: "e2", in: [other, entry])
        XCTAssertEqual(found?.id, entry.id)
        XCTAssertEqual(found?.sharedDetail, "课堂要点")
    }

    func testFindsSingleScheduleEntry() {
        let entry = HistoryEntry(
            title: "单次",
            baseDate: date(2026, 3, 1),
            reviewDates: [date(2026, 3, 1)],
            creationDate: Date(),
            type: .single,
            createdEventIdentifiers: ["s1"],
            sharedDetail: "备注"
        )
        XCTAssertEqual(
            HistorySeriesLookup.entry(containingEventId: "s1", in: [entry])?.id,
            entry.id
        )
    }

    func testReturnsNilWhenNoMatch() {
        let entry = HistoryEntry(
            title: "复习",
            baseDate: date(2026, 1, 1),
            reviewDates: [date(2026, 1, 4)],
            creationDate: Date(),
            createdEventIdentifiers: ["e1"]
        )
        XCTAssertNil(HistorySeriesLookup.entry(containingEventId: "missing", in: [entry]))
        XCTAssertNil(HistorySeriesLookup.entry(containingEventId: "e1", in: []))
    }

    func testSkipsEntriesWithEmptyIdentifiers() {
        let empty = HistoryEntry(
            title: "旧",
            baseDate: date(2026, 1, 1),
            reviewDates: [date(2026, 1, 4)],
            creationDate: Date(),
            createdEventIdentifiers: []
        )
        XCTAssertNil(HistorySeriesLookup.entry(containingEventId: "anything", in: [empty]))
    }

    func testFallsBackToTitleDayAndReviewKeyWhenIdentifierChanged() {
        let entry = HistoryEntry(
            title: "滑动窗口",
            baseDate: date(2026, 3, 1),
            reviewDates: [date(2026, 3, 4), date(2026, 3, 8)],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: ["old:A"]
        )
        let event = CalendarEventInfo(
            id: "new:Z",
            title: "滑动窗口",
            start: date(2026, 3, 8),
            end: date(2026, 3, 9),
            isAllDay: true,
            notes: "第2次复习\n提醒建议：当天 09:00",
            calendarId: "cal",
            calendarTitle: "日历",
            calendarSourceTitle: "163",
            colorHex: nil
        )

        XCTAssertEqual(HistorySeriesLookup.entry(matching: event, in: [entry])?.id, entry.id)
    }

    func testDoesNotFallBackWhenTitleDiffers() {
        let entry = HistoryEntry(
            title: "滑动窗口",
            baseDate: date(2026, 3, 1),
            reviewDates: [date(2026, 3, 4)],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: ["old:A"]
        )
        let event = CalendarEventInfo(
            id: "new:Z",
            title: "别的标题",
            start: date(2026, 3, 4),
            end: date(2026, 3, 5),
            isAllDay: true,
            notes: "第1次复习\n提醒建议：当天 09:00",
            calendarId: "cal",
            calendarTitle: "日历",
            calendarSourceTitle: "163",
            colorHex: nil
        )

        XCTAssertNil(HistorySeriesLookup.entry(matching: event, in: [entry]))
    }

    func testDoesNotFallBackWhenReviewDayDoesNotMatch() {
        let entry = HistoryEntry(
            title: "滑动窗口",
            baseDate: date(2026, 3, 1),
            reviewDates: [date(2026, 3, 4)],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: ["old:A"]
        )
        let event = CalendarEventInfo(
            id: "new:Z",
            title: "滑动窗口",
            start: date(2026, 3, 20),
            end: date(2026, 3, 21),
            isAllDay: true,
            notes: "第1次复习\n提醒建议：当天 09:00",
            calendarId: "cal",
            calendarTitle: "日历",
            calendarSourceTitle: "163",
            colorHex: nil
        )

        XCTAssertNil(HistorySeriesLookup.entry(matching: event, in: [entry]))
    }

    func testSingleScheduleNeverMatchesByAttributes() {
        let entry = HistoryEntry(
            title: "单次",
            baseDate: date(2026, 3, 4),
            reviewDates: [date(2026, 3, 4)],
            creationDate: Date(),
            type: .single,
            createdEventIdentifiers: ["old:A"]
        )
        let event = CalendarEventInfo(
            id: "new:Z",
            title: "单次",
            start: date(2026, 3, 4),
            end: date(2026, 3, 5),
            isAllDay: true,
            notes: "提醒建议：当天 09:00",
            calendarId: "cal",
            calendarTitle: "日历",
            calendarSourceTitle: "163",
            colorHex: nil
        )

        XCTAssertNil(HistorySeriesLookup.entry(matching: event, in: [entry]))
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}
