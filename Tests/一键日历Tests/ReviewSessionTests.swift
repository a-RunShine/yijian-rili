import XCTest
@testable import 一键日历

@MainActor
final class FakeWeeklyAppender: WeeklyEntryAppending {
    private(set) var appended: [HistoryEntry] = []
    private(set) var appendCallCount = 0
    private(set) var removedIDs: [UUID] = []
    private(set) var removeCallCount = 0

    func appendWeeklyEntry(from historyEntry: HistoryEntry) {
        appendCallCount += 1
        appended.append(historyEntry)
    }

    func removeWeeklyEntries(id: UUID) {
        removeCallCount += 1
        removedIDs.append(id)
        appended.removeAll { $0.id == id }
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

    func testRemoveEventsFromRecordedPartialThenDiscard() async throws {
        let suiteName = "series-remove-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "系列部分删"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        XCTAssertEqual(ids.count, 3)

        let partial = session.removeEventsFromRecorded(ids: [ids[0]])
        XCTAssertEqual(partial, .updated(id: batchID, remainingIdentifiers: Array(ids.dropFirst())))
        XCTAssertEqual(history.load().first?.createdEventIdentifiers.count, 2)
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        let rest = Array(ids.dropFirst())
        let full = session.removeEventsFromRecorded(ids: rest)
        XCTAssertEqual(full, .discarded(id: batchID))
        XCTAssertTrue(history.load().isEmpty)
        XCTAssertTrue(session.todayCreatedEntries().isEmpty)
        XCTAssertFalse(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDiscardRecordedContainingEventClearsTodayCreatedAndWeeklySource() async throws {
        let suiteName = "delete-today-weekly-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "搜索删除批次"
        session.baseDate = CreateSuccessTestSupport.date(2026, 2, 1)
        session.scheduleMode = .single
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let eventID = try XCTUnwrap(calendar.lastCreatedEventIdentifiers.first)
        XCTAssertEqual(session.todayCreatedEntries().map(\.id), [batchID])
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        XCTAssertTrue(calendar.deleteEvent(id: eventID))
        let discarded = session.discardRecordedContainingEvent(id: eventID)

        XCTAssertEqual(discarded, batchID)
        XCTAssertTrue(history.load().isEmpty)
        XCTAssertTrue(session.todayCreatedEntries().isEmpty)
        XCTAssertFalse(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testUndoAfterCreateClearsTodayCreatedAndWeeklySource() async throws {
        let suiteName = "undo-today-weekly-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "可撤销批次"
        session.baseDate = CreateSuccessTestSupport.date(2026, 2, 1)
        session.scheduleMode = .single
        await session.create()

        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(session.canUndo)
        let created = history.load()
        XCTAssertEqual(created.count, 1)
        let batchID = try XCTUnwrap(created.first?.id)
        XCTAssertEqual(session.todayCreatedEntries().map(\.id), [batchID])
        XCTAssertTrue(
            weekly.weeklyEntries.contains(where: { $0.id == batchID }),
            "周末总结 source must include the batch after create"
        )

        await session.undo()

        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(calendar.lastCreatedEventIdentifiers.isEmpty)
        XCTAssertTrue(history.load().isEmpty, "undo must remove 今日所建 batch from history")
        XCTAssertTrue(session.todayCreatedEntries().isEmpty)
        XCTAssertFalse(
            weekly.weeklyEntries.contains(where: { $0.id == batchID }),
            "周末总结 source must not include the undone batch"
        )

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCreateWithDetailWritesKeyFirstLineNotes() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, _) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "带备注"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.detail = "  课堂补充  "
        session.updateReviewDates()

        await session.create()

        XCTAssertEqual(session.resultType, .success)
        let events = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 3))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            events[0].notes,
            ReviewNotes.compose(key: "第1次复习", detail: "课堂补充")
        )
        XCTAssertEqual(NormalizeNotes.normalize(events[0].notes), "第1次复习")
        let entry = history.load().first
        XCTAssertEqual(entry?.sharedDetail, "课堂补充")
        XCTAssertEqual(entry?.createdEventIdentifiers, calendar.lastCreatedEventIdentifiers)
        XCTAssertEqual(entry?.createdEventIdentifiers.count, 3)
    }

    func testCreatePureSuccessPersistsIdsAndDetail_DuplicateDoesNot() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "门控"
        session.baseDate = CreateSuccessTestSupport.date(2026, 3, 1)
        session.scheduleMode = .single
        session.detail = "首次详情"

        await session.create()
        XCTAssertEqual(session.resultType, .success)
        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(history.load().first?.createdEventIdentifiers.count, 1)
        XCTAssertEqual(history.load().first?.sharedDetail, "首次详情")
        XCTAssertEqual(weekly.appendCallCount, 1)

        session.title = "门控"
        session.baseDate = CreateSuccessTestSupport.date(2026, 3, 1)
        session.scheduleMode = .single
        session.detail = "重复时不应写入"
        await session.create()
        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(history.load().first?.sharedDetail, "首次详情")
        XCTAssertEqual(weekly.appendCallCount, 1)
    }

    func testTodayCreatedEntriesFiltersByLocalCreationDay() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let defaults = CreateSuccessTestSupport.makeSuite()
        let (outcomes, history, _) = CreateSuccessTestSupport.makeOutcomes(defaults: defaults)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        let today = CreateSuccessTestSupport.date(2026, 4, 10)
        let yesterday = CreateSuccessTestSupport.date(2026, 4, 9)
        outcomes.record(HistoryEntry(
            title: "昨天",
            baseDate: yesterday,
            reviewDates: [],
            creationDate: yesterday,
            type: .single
        ))
        outcomes.record(HistoryEntry(
            title: "今天早",
            baseDate: today,
            reviewDates: [],
            creationDate: today.addingTimeInterval(3600),
            type: .review
        ))
        outcomes.record(HistoryEntry(
            title: "今天晚",
            baseDate: today,
            reviewDates: [],
            creationDate: today.addingTimeInterval(7200),
            type: .single
        ))

        let listed = session.todayCreatedEntries(now: today)
        XCTAssertEqual(listed.map(\.title), ["今天晚", "今天早"])
        XCTAssertTrue(session.todayCreatedEntries(now: yesterday.addingTimeInterval(86_400 * 2)).isEmpty)

        session.title = "会话新建"
        session.baseDate = today
        session.scheduleMode = .single
        await session.create()
        XCTAssertEqual(session.resultType, .success)
        let after = session.todayCreatedEntries(now: Date())
        XCTAssertEqual(after.first?.title, "会话新建")
        XCTAssertTrue(history.load().contains { $0.title == "会话新建" })
    }

    func testHistoryEntryDecodesMissingIdsAndDetail() throws {
        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"旧","baseDate":0,"reviewDates":[],"creationDate":0}
        """
        let data = Data(legacy.utf8)
        let entry = try JSONDecoder().decode(HistoryEntry.self, from: data)
        XCTAssertEqual(entry.title, "旧")
        XCTAssertEqual(entry.createdEventIdentifiers, [])
        XCTAssertNil(entry.sharedDetail)
        XCTAssertEqual(entry.type, .review)
    }

    func testUpdateSharedDetailRewritesOnlyDetailAcrossSeries() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "系列编辑"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.detail = "初始详情"
        session.updateReviewDates()
        await session.create()
        XCTAssertEqual(session.resultType, .success)
        let entry = try XCTUnwrap(history.load().first)
        XCTAssertEqual(entry.createdEventIdentifiers.count, 3)
        let weeklyBefore = weekly.appendCallCount

        let outcome = session.updateSharedDetail(for: entry, detail: "  修订后详情  ")

        XCTAssertEqual(outcome, .updated(updated: 3, missing: 0))
        XCTAssertEqual(session.resultType, .success)
        XCTAssertEqual(history.load().first?.sharedDetail, "修订后详情")
        XCTAssertEqual(weekly.appendCallCount, weeklyBefore)
        let d1 = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 3))
        let d2 = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 7))
        let d3 = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 3, 2))
        XCTAssertEqual(d1.count, 1)
        XCTAssertEqual(d1[0].notes, ReviewNotes.compose(key: "第1次复习", detail: "修订后详情"))
        XCTAssertEqual(d2[0].notes, ReviewNotes.compose(key: "第2次复习", detail: "修订后详情"))
        XCTAssertEqual(d3[0].notes, ReviewNotes.compose(key: "第3次复习", detail: "修订后详情"))
        XCTAssertEqual(NormalizeNotes.normalize(d1[0].notes), "第1次复习")
        XCTAssertEqual(NormalizeNotes.normalize(d2[0].notes), "第2次复习")
        XCTAssertEqual(NormalizeNotes.normalize(d3[0].notes), "第3次复习")
    }

    func testUpdateSharedDetailPartialSuccessWhenSomeEventsMissing() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, _) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "部分缺失"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.detail = "原详情"
        session.updateReviewDates()
        await session.create()
        let entry = try XCTUnwrap(history.load().first)
        let firstId = entry.createdEventIdentifiers[0]
        XCTAssertTrue(calendar.deleteEvent(id: firstId))

        let outcome = session.updateSharedDetail(for: entry, detail: "新详情")

        XCTAssertEqual(outcome, .updated(updated: 2, missing: 1))
        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(history.load().first?.sharedDetail, "新详情")
        let surviving = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 7))
        XCTAssertEqual(
            surviving[0].notes,
            ReviewNotes.compose(key: "第2次复习", detail: "新详情")
        )
    }

    func testUpdateSharedDetailUnavailableForEmptyIdentifiers() {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        let legacy = HistoryEntry(
            title: "旧批次",
            baseDate: CreateSuccessTestSupport.date(2026, 1, 1),
            reviewDates: [],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: [],
            sharedDetail: "残留"
        )
        history.add(legacy)
        let weeklyBefore = weekly.appendCallCount

        let outcome = session.updateSharedDetail(for: legacy, detail: "不应写入")

        XCTAssertEqual(outcome, .unavailable)
        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(history.load().first?.sharedDetail, "残留")
        XCTAssertEqual(weekly.appendCallCount, weeklyBefore)
        XCTAssertTrue(calendar.fetchEvents(on: Date()).isEmpty)
    }

    func testCommitIntervalDraftSuccessUpdatesPreview() {
        let (session, _, _) = CreateSuccessTestSupport.makeSession()
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        let before = session.reviewDates

        let result = session.commitIntervalDraft(["1", "2", "4"])
        guard case .success(let intervals) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(intervals, [1, 2, 4])
        XCTAssertEqual(session.reviewIntervals, [1, 2, 4])
        XCTAssertEqual(session.reviewDates.count, 3)
        XCTAssertNotEqual(session.reviewDates, before)
    }

    func testCommitIntervalDraftFailureLeavesStateUnchanged() {
        let (session, _, _) = CreateSuccessTestSupport.makeSession()
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        let intervalsBefore = session.reviewIntervals
        let datesBefore = session.reviewDates

        let result = session.commitIntervalDraft(["30", "7", "3"])
        XCTAssertEqual(result, .failure(.notIncreasingAt(2)))
        XCTAssertEqual(session.reviewIntervals, intervalsBefore)
        XCTAssertEqual(session.reviewDates, datesBefore)
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

    func testDisplayedEventsExposeExtractableNotesDetailForEachDay() async throws {
        let calendar = InMemoryCalendarService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        _ = try await calendar.createSingleEvent(
            title: "昨日条目", date: yesterday, calendarId: nil, detail: "昨详情"
        )
        _ = try await calendar.createReviewEvents(
            title: "今日复习",
            baseDate: cal.date(byAdding: .day, value: -3, to: today)!,
            intervals: [3, 7, 30],
            calendarId: nil,
            detail: "今详情"
        )
        _ = try await calendar.createSingleEvent(
            title: "明日条目", date: tomorrow, calendarId: nil, detail: "明详情"
        )

        let browse = DayBrowseModel(calendar: calendar)

        browse.selectDayType(.yesterday)
        XCTAssertEqual(
            browse.displayedEvents.map { NotesDetail.extract($0.notes) },
            ["昨详情"]
        )

        browse.selectDayType(.today)
        let todayDetails = browse.displayedEvents.map { NotesDetail.extract($0.notes) }
        XCTAssertTrue(todayDetails.contains("今详情"))

        browse.selectDayType(.tomorrow)
        XCTAssertEqual(
            browse.displayedEvents.map { NotesDetail.extract($0.notes) },
            ["明详情"]
        )
    }
}
