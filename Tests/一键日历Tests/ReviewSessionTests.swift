import XCTest
@testable import 一键日历

@MainActor
final class ReviewSessionTests: XCTestCase {
    func testCreateSuccessWithInMemoryCalendar() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let session = ReviewSession(calendar: calendar)
        session.title = "会话创建"
        session.baseDate = date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.updateReviewDates()

        await session.create()

        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(calendar.lastCreatedEventIdentifiers.count, 3)
        XCTAssertNotNil(session.consumePendingHistoryEntry())
        XCTAssertTrue(session.title.isEmpty)
    }

    func testCreateRejectsEmptyAndLongTitle() async {
        let session = ReviewSession(calendar: InMemoryCalendarService())
        session.title = "  "
        await session.create()
        XCTAssertEqual(session.resultType, .error)

        session.title = String(repeating: "a", count: 101)
        await session.create()
        XCTAssertEqual(session.resultType, .error)
    }

    func testUndoAfterCreate() async {
        let calendar = InMemoryCalendarService()
        let session = ReviewSession(calendar: calendar)
        session.title = "可撤销"
        session.baseDate = date(2026, 2, 1)
        session.scheduleMode = .single
        await session.create()
        XCTAssertTrue(session.canUndo)

        await session.undo()
        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(calendar.lastCreatedEventIdentifiers.isEmpty)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}

@MainActor
final class DayBrowseModelTests: XCTestCase {
    func testFetchSearchAndDelete() async throws {
        let calendar = InMemoryCalendarService()
        _ = try await calendar.createSingleEvent(title: "Browse Me", date: Date(), calendarId: nil)
        let browse = DayBrowseModel(calendar: calendar)
        browse.loadDisplayedDayEvents()
        XCTAssertFalse(browse.displayedEvents.isEmpty)

        browse.searchText = "browse"
        browse.performSearch()
        XCTAssertEqual(browse.searchResults.count, 1)

        let event = browse.searchResults[0]
        XCTAssertTrue(browse.deleteSearchResult(event))
        browse.performSearch()
        XCTAssertTrue(browse.searchResults.isEmpty)
    }
}
