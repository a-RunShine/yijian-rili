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

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}
