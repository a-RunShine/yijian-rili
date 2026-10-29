import XCTest
@testable import 一键日历

@MainActor
final class FakeWeeklyAppender: WeeklyEntryAppending {
    private(set) var appended: [HistoryEntry] = []
    private(set) var appendCallCount = 0
    private(set) var removedIDs: [UUID] = []
    private(set) var removeCallCount = 0
    private(set) var titleUpdates: [(UUID, String)] = []

    func appendWeeklyEntry(from historyEntry: HistoryEntry) {
        appendCallCount += 1
        appended.append(historyEntry)
    }

    func removeWeeklyEntries(id: UUID) {
        removeCallCount += 1
        removedIDs.append(id)
        appended.removeAll { $0.id == id }
    }

    func updateWeeklyEntryTitle(id: UUID, title: String) {
        titleUpdates.append((id, title))
        appended = appended.map { entry in
            guard entry.id == id else { return entry }
            return HistoryEntry(
                id: entry.id,
                title: title,
                baseDate: entry.baseDate,
                reviewDates: entry.reviewDates,
                creationDate: entry.creationDate,
                type: entry.type,
                createdEventIdentifiers: entry.createdEventIdentifiers,
                sharedDetail: entry.sharedDetail
            )
        }
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

    static func makeSessionWithRealWeekly(
        calendar: CalendarService = InMemoryCalendarService(grantAccessByDefault: true)
    ) -> (ReviewSession, HistoryStore, WeeklyReviewViewModel, UserDefaults) {
        let suiteName = "reconcile-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)
        return (session, history, weekly, defaults)
    }

    static func seedReviewBatch(
        _ session: ReviewSession,
        title: String,
        on defaults: UserDefaults
    ) async throws -> ([String], UUID) {
        session.title = title
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()
        let history = HistoryStore(defaults: defaults)
        let entry = try XCTUnwrap(history.load().first)
        return (entry.createdEventIdentifiers, entry.id)
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
        let writeDay = CreateSuccessTestSupport.date(2026, 1, 31)
        session.title = "会话创建"
        session.detail = "写入后应清空"
        session.baseDate = writeDay
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.reviewDates = [CreateSuccessTestSupport.date(2026, 1, 1)]

        await session.create()

        XCTAssertEqual(session.resultType, .success)
        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(history.load().first?.liveEventIdentifiers.count, 3)
        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(history.load().first?.title, "会话创建")
        XCTAssertEqual(weekly.appendCallCount, 1)
        XCTAssertTrue(session.title.isEmpty)
        XCTAssertTrue(session.detail.isEmpty)
        XCTAssertEqual(session.baseDate, writeDay)
        XCTAssertEqual(session.reviewDates, [
            CreateSuccessTestSupport.date(2026, 2, 3),
            CreateSuccessTestSupport.date(2026, 2, 7),
            CreateSuccessTestSupport.date(2026, 3, 2),
        ])
        XCTAssertEqual(session.resultMessage, Self.writtenCountMessage(3))
    }

    func testSingleCreateSuccessCopyCountsTheWrittenEvent() async {
        let (session, _, _) = CreateSuccessTestSupport.makeSession()
        session.title = "单次"
        session.baseDate = CreateSuccessTestSupport.date(2026, 4, 2)
        session.scheduleMode = .single

        await session.create()

        XCTAssertEqual(session.resultType, .success)
        XCTAssertEqual(session.resultMessage, Self.writtenCountMessage(1))
        XCTAssertTrue(session.canUndo)
    }

    func testUndoSuccessCopyCountsDeletedEventsWithoutTitle() async {
        let (session, _, _) = CreateSuccessTestSupport.makeSession()
        session.title = "可撤销三件"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        await session.create()

        await session.undo()

        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session.resultType, .success)
        XCTAssertEqual(session.resultMessage, Self.undoneCountMessage(3))
    }

    func testPartialDuplicateStaysWarningAndRecordsWhatWasWritten() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        let base = CreateSuccessTestSupport.date(2026, 1, 31)
        let duplicateDay = CreateSuccessTestSupport.date(2026, 2, 3)
        let freshDay = CreateSuccessTestSupport.date(2026, 2, 7)
        session.title = "部分新写入"
        session.baseDate = base
        session.scheduleMode = .review
        session.reviewIntervals = [3]
        await session.create()
        XCTAssertEqual(history.load().count, 1)
        XCTAssertEqual(weekly.appendCallCount, 1)

        session.title = "部分新写入"
        session.reviewIntervals = [3, 7]
        await session.create()

        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(
            session.resultMessage,
            String(format: NSLocalizedString("warning_message", comment: ""), duplicateDay.formattedChinese())
        )
        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(history.load().count, 2)
        XCTAssertEqual(weekly.appendCallCount, 2)
        XCTAssertEqual(calendar.fetchEvents(on: freshDay).map(\.title), ["部分新写入"])
        let recorded = history.load().first { entry in
            entry.reviewDates.contains { Calendar.current.isDate($0, inSameDayAs: freshDay) }
        }
        XCTAssertNotNil(recorded)

        await session.undo()

        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session.resultMessage, Self.undoneCountMessage(2))
        XCTAssertEqual(history.load().count, 1)
        XCTAssertTrue(calendar.fetchEvents(on: freshDay).isEmpty)
        XCTAssertFalse(calendar.fetchEvents(on: duplicateDay).isEmpty)
    }

    func testDuplicateOnlyCreateDoesNotEnableUndo() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let base = CreateSuccessTestSupport.date(2026, 3, 1)
        _ = try await calendar.createSingleEvent(title: "已有", date: base, calendarId: nil)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "已有"
        session.baseDate = base
        session.scheduleMode = .single

        await session.create()

        XCTAssertEqual(session.resultType, .warning)
        XCTAssertFalse(session.canUndo)
        XCTAssertTrue(history.load().isEmpty)
        XCTAssertEqual(weekly.appendCallCount, 0)
    }

    private static func writtenCountMessage(_ count: Int) -> String {
        String(format: NSLocalizedString("write_success_count", comment: ""), count)
    }

    private static func undoneCountMessage(_ count: Int) -> String {
        String(format: NSLocalizedString("undo_success_count", comment: ""), count)
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

        let partial = session.removeEventsFromRecorded(ids: [ids[0]], reason: .userDeletedOccurrence)
        XCTAssertEqual(partial, .updated(id: batchID, remainingIdentifiers: Array(ids.dropFirst())))
        XCTAssertEqual(history.load().first?.liveEventIdentifiers.count, 2)
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        let rest = Array(ids.dropFirst())
        let full = session.removeEventsFromRecorded(ids: rest, reason: .userDeletedOccurrence)
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
        let eventID = try XCTUnwrap(history.load().first?.liveEventIdentifiers.first)
        XCTAssertEqual(session.todayCreatedEntries().map(\.id), [batchID])
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        XCTAssertTrue(calendar.removeExternally(id: eventID))
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
        XCTAssertTrue(
            calendar.fetchEvents(
                from: Date().addingTimeInterval(-86_400),
                to: Date().addingTimeInterval(86_400 * 3)
            ).isEmpty,
            "撤销后日历里不该还剩刚写进去的事件"
        )
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
        XCTAssertEqual(entry?.liveEventIdentifiers.count, 3)
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
        XCTAssertEqual(history.load().first?.liveEventIdentifiers.count, 1)
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
        XCTAssertEqual(entry.liveEventIdentifiers.count, 3)
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
        XCTAssertTrue(calendar.removeExternally(id: firstId))

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

    func testUpdateSeriesTitleRewritesAllMembersAndHistoryAndWeekly() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "旧系列名"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.updateReviewDates()
        await session.create()
        XCTAssertEqual(session.resultType, .success)
        let entry = try XCTUnwrap(history.load().first)
        XCTAssertEqual(entry.liveEventIdentifiers.count, 3)
        XCTAssertEqual(weekly.appended.first?.title, "旧系列名")

        let outcome = session.updateSeriesTitle(for: entry, title: "  新系列名  ")

        XCTAssertEqual(outcome, .updated(updated: 3, missing: 0))
        XCTAssertEqual(session.resultType, .success)
        XCTAssertEqual(history.load().first?.title, "新系列名")
        XCTAssertEqual(weekly.titleUpdates.count, 1)
        XCTAssertEqual(weekly.titleUpdates.first?.0, entry.id)
        XCTAssertEqual(weekly.titleUpdates.first?.1, "新系列名")
        XCTAssertEqual(weekly.appended.first?.title, "新系列名")
        let d1 = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 3))
        let d2 = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 7))
        let d3 = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 3, 2))
        XCTAssertEqual(d1[0].title, "新系列名")
        XCTAssertEqual(d2[0].title, "新系列名")
        XCTAssertEqual(d3[0].title, "新系列名")
    }

    func testUpdateSeriesTitlePartialSuccessWhenSomeEventsMissing() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "部分改名"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3, 7, 30]
        session.scheduleMode = .review
        session.updateReviewDates()
        await session.create()
        let entry = try XCTUnwrap(history.load().first)
        let firstId = entry.createdEventIdentifiers[0]
        XCTAssertTrue(calendar.removeExternally(id: firstId))

        let outcome = session.updateSeriesTitle(for: entry, title: "改后名")

        XCTAssertEqual(outcome, .updated(updated: 2, missing: 1))
        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(history.load().first?.title, "改后名")
        XCTAssertEqual(weekly.titleUpdates.first?.1, "改后名")
        let surviving = calendar.fetchEvents(on: CreateSuccessTestSupport.date(2026, 2, 7))
        XCTAssertEqual(surviving[0].title, "改后名")
    }

    func testUpdateSeriesTitleUnavailableForEmptyIdentifiers() {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        let legacy = HistoryEntry(
            title: "旧批次",
            baseDate: CreateSuccessTestSupport.date(2026, 1, 1),
            reviewDates: [],
            creationDate: Date(),
            type: .review,
            createdEventIdentifiers: [],
            sharedDetail: nil
        )
        history.add(legacy)

        let outcome = session.updateSeriesTitle(for: legacy, title: "不应写入")

        XCTAssertEqual(outcome, .unavailable)
        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(history.load().first?.title, "旧批次")
        XCTAssertTrue(weekly.titleUpdates.isEmpty)
    }

    func testUpdateSeriesTitleAllMissingDoesNotChangeHistoryOrWeekly() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, weekly) = CreateSuccessTestSupport.makeSession(calendar: calendar)
        session.title = "全缺失"
        session.baseDate = CreateSuccessTestSupport.date(2026, 1, 31)
        session.reviewIntervals = [3]
        session.scheduleMode = .review
        session.updateReviewDates()
        await session.create()
        let entry = try XCTUnwrap(history.load().first)
        XCTAssertTrue(calendar.removeExternally(id: entry.createdEventIdentifiers[0]))

        let outcome = session.updateSeriesTitle(for: entry, title: "不会落库")

        XCTAssertEqual(outcome, .updated(updated: 0, missing: 1))
        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(history.load().first?.title, "全缺失")
        XCTAssertTrue(weekly.titleUpdates.isEmpty)
    }

    func testReconcileKeepsAllIdsWhenOneLookupMisses() async throws {
        let suiteName = "reconcile-partial-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "对账部分缺失"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(calendar.removeExternally(id: ids[0]))
        session.resultMessage = nil
        session.resultType = nil

        session.reconcileRecordedWithCalendar()

        let after = try XCTUnwrap(history.load().first)
        XCTAssertEqual(after.id, batchID)
        XCTAssertEqual(after.createdEventIdentifiers, ids)
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))
        XCTAssertTrue(session.todayCreatedEntries().contains(where: { $0.id == batchID }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReconcileKeepsBatchWhenAllCalendarEventsLookupsMiss() async throws {
        let suiteName = "reconcile-all-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "对账全部缺失"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        for id in ids {
            XCTAssertTrue(calendar.removeExternally(id: id))
        }
        session.resultMessage = nil
        session.resultType = nil

        let changed = session.reconcileRecordedWithCalendar()

        XCTAssertEqual(changed, .unmatched(count: 3))
        let after = try XCTUnwrap(history.load().first)
        XCTAssertEqual(after.id, batchID)
        XCTAssertEqual(after.createdEventIdentifiers, ids)
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        defaults.removePersistentDomain(forName: suiteName)
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
    func testFetchAndSearch() async throws {
        let calendar = InMemoryCalendarService()
        _ = try await calendar.createSingleEvent(title: "Browse Me", date: Date(), calendarId: nil)
        let browse = DayBrowseModel(calendar: calendar)
        browse.loadDisplayedDayEvents()
        XCTAssertFalse(browse.displayedEvents.isEmpty)

        browse.searchText = "browse"
        browse.performSearch()
        XCTAssertEqual(browse.searchResults.count, 1)
    }

    func testDeletingSoleSearchResultThroughFacadeLeavesSearchEmpty() async throws {
        let calendar = InMemoryCalendarService()
        _ = try await calendar.createSingleEvent(title: "Browse Delete", date: Date(), calendarId: nil)
        let (viewModel, isolated) = makeIsolatedViewModel(calendar: calendar)
        addTeardownBlock { isolated.cleanUp() }

        viewModel.searchText = "browse delete"
        viewModel.performSearch()
        let hit = try XCTUnwrap(viewModel.searchHits.first)

        XCTAssertTrue(viewModel.deleteSearchHit(hit))

        viewModel.performSearch()
        XCTAssertTrue(viewModel.searchHits.isEmpty)
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

@MainActor
final class OccurrenceStatusTests: XCTestCase {
    func testMarkDonePersistsAcrossSessionReload() async throws {
        let suiteName = "occurrence-done-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: statuses)

        session.title = "完成态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let eventId = try XCTUnwrap(history.load().first?.createdEventIdentifiers.first)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .unmarked)

        session.setOccurrenceStatus(eventId: eventId, status: .done)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .done)

        let reloaded = OccurrenceStatusStore(defaults: defaults)
        let session2 = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: reloaded)
        XCTAssertEqual(session2.occurrenceStatus(for: eventId), .done)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testMarkSkippedShowsInWeeklyMaterialsWithoutTouchingReviewedIds() async throws {
        let suiteName = "occurrence-weekly-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: statuses)

        let today = Calendar.current.startOfDay(for: Date())
        session.title = "跳过素材"
        session.baseDate = today
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let eventId = try XCTUnwrap(history.load().first?.createdEventIdentifiers.first)
        weekly.toggleReviewed(batchID)
        let reviewedBefore = weekly.reviewedIds

        session.setOccurrenceStatus(eventId: eventId, status: .skipped)

        let weekStart = WeekCalculator.weekStart(for: today)
        let weekEnd = WeekCalculator.weekEnd(for: weekStart)
        let materials = session.occurrenceMaterials(weekStart: weekStart, weekEnd: weekEnd)
        XCTAssertEqual(materials.count, 1)
        XCTAssertEqual(materials[0].eventId, eventId)
        XCTAssertEqual(materials[0].status, .skipped)
        XCTAssertEqual(materials[0].title, "跳过素材")
        XCTAssertEqual(weekly.reviewedIds, reviewedBefore)
        XCTAssertTrue(weekly.reviewedIds.contains(batchID))

        weekly.occurrenceMaterialProvider = { start, end in
            session.occurrenceMaterials(weekStart: start, weekEnd: end)
        }
        let display = weekly.occurrenceMaterialsInCurrentWeek
        XCTAssertEqual(display.count, 1)
        XCTAssertEqual(display[0].status, .skipped)
        XCTAssertEqual(display[0].eventId, eventId)
        XCTAssertEqual(weekly.reviewedIds, reviewedBefore)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOccurrenceStatusToggleAndMutualExclusion() async throws {
        let suiteName = "occurrence-toggle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: statuses)

        session.title = "互斥完成态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let eventId = try XCTUnwrap(history.load().first?.createdEventIdentifiers.first)

        session.setOccurrenceStatus(eventId: eventId, status: .done)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .done)
        session.setOccurrenceStatus(eventId: eventId, status: .unmarked)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .unmarked)

        session.setOccurrenceStatus(eventId: eventId, status: .skipped)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .skipped)
        session.setOccurrenceStatus(eventId: eventId, status: .unmarked)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .unmarked)

        session.setOccurrenceStatus(eventId: eventId, status: .done)
        session.setOccurrenceStatus(eventId: eventId, status: .skipped)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .skipped)
        session.setOccurrenceStatus(eventId: eventId, status: .done)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .done)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testOccurrenceStatusIgnoresNonReviewEventsAndMaterials() async throws {
        let suiteName = "occurrence-scope-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: statuses)

        let today = Calendar.current.startOfDay(for: Date())
        session.title = "单次不进进度"
        session.baseDate = today
        session.scheduleMode = .single
        session.updateReviewDates()
        await session.create()

        let eventId = try XCTUnwrap(history.load().first?.createdEventIdentifiers.first)
        session.setOccurrenceStatus(eventId: eventId, status: .done)
        XCTAssertEqual(session.occurrenceStatus(for: eventId), .unmarked)

        session.setOccurrenceStatus(eventId: "holiday-orphan", status: .skipped)
        XCTAssertEqual(session.occurrenceStatus(for: "holiday-orphan"), .unmarked)

        let weekStart = WeekCalculator.weekStart(for: today)
        let weekEnd = WeekCalculator.weekEnd(for: weekStart)
        XCTAssertTrue(session.occurrenceMaterials(weekStart: weekStart, weekEnd: weekEnd).isEmpty)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRemoveEventsFromRecordedClearsOccurrenceStatus() async throws {
        let suiteName = "occurrence-clear-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: statuses)

        session.title = "清理完成态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        XCTAssertEqual(ids.count, 3)
        session.setOccurrenceStatus(eventId: ids[0], status: .done)
        session.setOccurrenceStatus(eventId: ids[1], status: .skipped)
        XCTAssertEqual(session.occurrenceStatus(for: ids[0]), .done)

        _ = session.removeEventsFromRecorded(ids: [ids[0]], reason: .userDeletedOccurrence)

        XCTAssertEqual(session.occurrenceStatus(for: ids[0]), .unmarked)
        XCTAssertEqual(session.occurrenceStatus(for: ids[1]), .skipped)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReconcileKeepsOccurrenceStatusWhenLookupMisses() async throws {
        let suiteName = "occurrence-reconcile-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes, occurrenceStatuses: statuses)

        session.title = "对账清完成态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        session.setOccurrenceStatus(eventId: ids[0], status: .done)
        session.setOccurrenceStatus(eventId: ids[1], status: .skipped)
        XCTAssertTrue(calendar.removeExternally(id: ids[0]))

        session.reconcileRecordedWithCalendar()

        XCTAssertEqual(session.occurrenceStatus(for: ids[0]), .done)
        XCTAssertEqual(session.occurrenceStatus(for: ids[1]), .skipped)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReconcileWithoutFullAccessLeavesHistoryUntouched() async throws {
        let suiteName = "reconcile-noauth-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "无权限对账"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        XCTAssertEqual(ids.count, 3)

        calendar.setAuthorizationStatusForTesting(.notDetermined)
        calendar.eventsUnreadable = true
        session.authorizationStatus = .notDetermined

        let changed = session.reconcileRecordedWithCalendar()

        XCTAssertEqual(changed, .skippedNoAccess)
        let after = try XCTUnwrap(history.load().first)
        XCTAssertEqual(after.id, batchID)
        XCTAssertEqual(after.createdEventIdentifiers, ids)
        XCTAssertTrue(weekly.weeklyEntries.contains(where: { $0.id == batchID }))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReconcileWithoutFullAccessDoesNotDiscardBatchEvenWhenEventsUnreadable() async throws {
        let suiteName = "reconcile-noauth-keep-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "无权限不可丢"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let batchID = try XCTUnwrap(history.load().first?.id)
        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)

        calendar.setAuthorizationStatusForTesting(.denied)
        calendar.eventsUnreadable = true
        session.authorizationStatus = .denied

        session.reconcileRecordedWithCalendar()

        let after = try XCTUnwrap(history.load().first)
        XCTAssertEqual(after.id, batchID)
        XCTAssertEqual(after.createdEventIdentifiers, ids)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testReconcileReportsUnmatchedOnceAccessIsReadyWithoutPruning() async throws {
        let suiteName = "reconcile-resume-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "恢复对账"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)

        calendar.setAuthorizationStatusForTesting(.notDetermined)
        session.authorizationStatus = .notDetermined
        session.reconcileRecordedWithCalendar()
        XCTAssertEqual(history.load().first?.createdEventIdentifiers, ids)

        calendar.setAuthorizationStatusForTesting(.fullAccess)
        session.authorizationStatus = .fullAccess
        XCTAssertTrue(calendar.removeExternally(id: ids[0]))
        let outcome = session.reconcileRecordedWithCalendar()

        XCTAssertEqual(outcome, .unmatched(count: 1))
        XCTAssertEqual(history.load().first?.createdEventIdentifiers, ids)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCalendarConfirmedMissingCannotBeConstructedWithoutFullAccess() {
        XCTAssertNil(CalendarLookupAuthority.verified(.notDetermined))
        XCTAssertNil(CalendarLookupAuthority.verified(.denied))
        XCTAssertNil(CalendarLookupAuthority.verified(.restricted))
        XCTAssertNotNil(CalendarLookupAuthority.verified(.fullAccess))
    }

    func testDirectPruneByUserStillWorksWithoutAccess() async throws {
        let suiteName = "prune-user-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "用户删除"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)

        session.authorizationStatus = .denied
        let outcome = session.removeEventsFromRecorded(ids: [ids[0]], reason: .userDeletedOccurrence)

        XCTAssertEqual(outcome, .updated(id: history.load().first!.id, remainingIdentifiers: Array(ids.dropFirst())))

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSeriesStaysEditableAfterCalendarReassignsEveryIdentifier() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, _, defaults) = CreateSuccessTestSupport.makeSessionWithRealWeekly(calendar: calendar)
        let (ids, batchID) = try await CreateSuccessTestSupport.seedReviewBatch(
            session,
            title: "CalDAV 重分配",
            on: defaults
        )
        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(session.canMarkOccurrence(eventId: ids[0]))

        let remapped = calendar.reassignAllEventIdentifiersForTesting()
        let freshIds = ids.compactMap { remapped[$0] }
        XCTAssertEqual(freshIds.count, 3)

        session.reconcileRecordedWithCalendar()

        XCTAssertTrue(
            session.canMarkOccurrence(eventId: freshIds[0]),
            "CalDAV 重新分配 id 后，系列仍应可标记完成"
        )
        XCTAssertTrue(
            history.load().contains(where: { $0.id == batchID })
        )

    }
}
