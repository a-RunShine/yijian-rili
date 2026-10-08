import XCTest
@testable import 一键日历

@MainActor
final class FakeWeeklyAppender: WeeklyEntryAppending {
    private(set) var appended: [HistoryEntry] = []
    private(set) var appendCallCount = 0

    func appendWeeklyEntry(from historyEntry: HistoryEntry) {
        appendCallCount += 1
        appended.append(historyEntry)
    }
}

@MainActor
enum CreateSuccessTestSupport {
    static func makeSuite() -> UserDefaults {
        let name = "c4-test-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    static func makeOutcomes(defaults: UserDefaults) -> (CreateSuccessOutcomes, HistoryStore, FakeWeeklyAppender) {
        let history = HistoryStore(defaults: defaults)
        let weekly = FakeWeeklyAppender()
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        return (outcomes, history, weekly)
    }

    static func makeSession(
        calendar: CalendarService = InMemoryCalendarService(grantAccessByDefault: true),
        defaults: UserDefaults? = nil
    ) -> (ReviewSession, HistoryStore, FakeWeeklyAppender) {
        let suite = defaults ?? makeSuite()
        let (outcomes, history, weekly) = makeOutcomes(defaults: suite)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)
        return (session, history, weekly)
    }

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }
}

@MainActor
final class CreateSuccessOutcomesTests: XCTestCase {
    func testRecordWritesHistoryAndWeekly() {
        let defaults = CreateSuccessTestSupport.makeSuite()
        let (outcomes, history, weekly) = CreateSuccessTestSupport.makeOutcomes(defaults: defaults)
        let entry = HistoryEntry(
            title: "双写",
            baseDate: CreateSuccessTestSupport.date(2026, 3, 1),
            reviewDates: [CreateSuccessTestSupport.date(2026, 3, 4)],
            creationDate: Date(),
            type: .review
        )

        outcomes.record(entry)

        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(history.load().first?.title, "双写")
        XCTAssertEqual(weekly.appendCallCount, 1)
        XCTAssertEqual(weekly.appended.first?.id, entry.id)
    }

    func testHistoryCapDoesNotLimitWeeklyAppenderCalls() {
        let defaults = CreateSuccessTestSupport.makeSuite()
        let (outcomes, history, weekly) = CreateSuccessTestSupport.makeOutcomes(defaults: defaults)

        for i in 0..<25 {
            let entry = HistoryEntry(
                title: "条目\(i)",
                baseDate: CreateSuccessTestSupport.date(2026, 1, 1),
                reviewDates: [],
                creationDate: Date(),
                type: .single
            )
            outcomes.record(entry)
        }

        XCTAssertEqual(history.load().count, HistoryStore.maxEntries)
        XCTAssertEqual(weekly.appendCallCount, 25)
    }

    func testClearAndRemoveDoNotTouchWeekly() {
        let defaults = CreateSuccessTestSupport.makeSuite()
        let (outcomes, history, weekly) = CreateSuccessTestSupport.makeOutcomes(defaults: defaults)
        let entry = HistoryEntry(
            title: "可删",
            baseDate: Date(),
            reviewDates: [],
            creationDate: Date(),
            type: .single
        )
        outcomes.record(entry)
        XCTAssertEqual(weekly.appendCallCount, 1)

        outcomes.removeHistory(id: entry.id)
        XCTAssertTrue(history.load().isEmpty)
        XCTAssertEqual(weekly.appendCallCount, 1, "remove 不得再调 weekly")

        outcomes.record(HistoryEntry(
            title: "再写",
            baseDate: Date(),
            reviewDates: [],
            creationDate: Date(),
            type: .review
        ))
        outcomes.clearHistory()
        XCTAssertTrue(history.load().isEmpty)
        XCTAssertEqual(weekly.appendCallCount, 2, "clear 不得再调 weekly")
    }
}

@MainActor
final class ReviewSessionTests: XCTestCase {
    func testCreateSuccessWithInMemoryCalendar() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "会话创建"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.updateReviewDates()

        await session.create()

        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(calendar.lastCreatedEventIdentifiers.count, 3)
        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(history.load().first?.title, "会话创建")
        XCTAssertEqual(weekly.appendCallCount, 1)
        XCTAssertTrue(session.title.isEmpty)
    }

    func testCreateRejectsEmptyAndLongTitle() async {
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession()
        session.title = "  "
        await session.create()
        XCTAssertEqual(session.resultType, .error)
        XCTAssertTrue(history.load().isEmpty)
        XCTAssertEqual(weekly.appendCallCount, 0)

        session.title = String(repeating: "a", count: 101)
        await session.create()
        XCTAssertEqual(session.resultType, .error)
        XCTAssertEqual(weekly.appendCallCount, 0)
    }

    func testUndoAfterCreateDoesNotClearHistoryOrWeekly() async {
        let calendar = InMemoryCalendarService()
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "可撤销"
        session.baseDate = CreateSuccessTestSupport.date(2026, 2, 1)
        session.scheduleMode = .single
        await session.create()
        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(weekly.appendCallCount, 1)

        await session.undo()
        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(calendar.lastCreatedEventIdentifiers.isEmpty)
        XCTAssertEqual(history.load().count, 1, "undo 不删历史")
        XCTAssertEqual(weekly.appendCallCount, 1, "undo 不触达 weekly")
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
