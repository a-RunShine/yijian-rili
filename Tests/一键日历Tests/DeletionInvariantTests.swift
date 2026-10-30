import XCTest
@testable import 一键日历

@MainActor
final class DeletionInvariantTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let isolated = makeIsolatedDefaults()
        addTeardownBlock { isolated.cleanUp() }
        return isolated.defaults
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }

    private func makeSeries(
        _ viewModel: ReviewViewModel,
        marker: String
    ) async throws -> HistoryEntry {
        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()
        return try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
    }

    private func events(_ calendar: InMemoryCalendarService) -> [CalendarEventInfo] {
        calendar.fetchEvents(from: date(2026, 10, 1), to: date(2026, 12, 31))
    }

    func testSlotsStayAlignedWithReviewDatesAfterDeletingFromHistoryPanel() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let batch = try await makeSeries(viewModel, marker: "槽位对齐-\(UUID().uuidString.prefix(6))")
        let middle = try XCTUnwrap(batch.createdEventIdentifiers.dropFirst().first)

        viewModel.deleteHistoryEntry(batch, members: [middle])

        let remaining = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
        XCTAssertEqual(
            remaining.createdEventIdentifiers.count,
            remaining.reviewDates.count,
            "槽位数量必须与复习日数量一致，否则后面的成员会串位"
        )
        XCTAssertEqual(
            remaining.createdEventIdentifiers[1],
            "",
            "删掉的中间成员应留空槽，而不是让后面的成员顶上来"
        )
        XCTAssertEqual(remaining.liveEventIdentifiers.count, 2)
    }

    func testDeletingWholeSeriesFromMainScreenClearsOccurrenceStatus() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let defaults = freshDefaults()
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: defaults)
        let batch = try await makeSeries(viewModel, marker: "主界面清标记-\(UUID().uuidString.prefix(6))")

        for (index, id) in batch.createdEventIdentifiers.enumerated() {
            viewModel.setOccurrenceStatus(eventId: id, status: index == 0 ? .done : .skipped)
        }
        XCTAssertFalse(statuses.markedEntries().isEmpty, "三条都该标上")

        for id in batch.createdEventIdentifiers {
            let entry = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
            let member = try XCTUnwrap(
                entry.liveEventIdentifiers.first(where: { $0 == id })
                    ?? entry.liveEventIdentifiers.first
            )
            let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: member, on: date(2026, 10, 27)))
            viewModel.deleteSearchHit(hit)
        }

        XCTAssertFalse(viewModel.historyEntries.contains { $0.id == batch.id })
        XCTAssertTrue(
            statuses.markedEntries().isEmpty,
            "整个系列删完后，该系列的完成标记不该残留成孤儿"
        )
    }

    func testDeletingRecordWhoseEventsAllVanishedStillClearsRecord() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let batch = try await makeSeries(viewModel, marker: "全部已不在-\(UUID().uuidString.prefix(6))")

        for id in batch.createdEventIdentifiers {
            calendar.removeExternally(id: id)
        }
        XCTAssertTrue(events(calendar).isEmpty)

        let entry = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
        viewModel.deleteHistoryEntry(entry, members: entry.createdEventIdentifiers)

        XCTAssertFalse(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "日历里已经没有这条记录的任何事件时，删除不该什么都不做"
        )
        XCTAssertNotEqual(viewModel.resultType, .warning, "本来就不在不算失败")
    }

    func testEmptyMembershipDoesNotCrashAndReportsNothingDeleted() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let batch = try await makeSeries(viewModel, marker: "无成员-\(UUID().uuidString.prefix(6))")

        for id in batch.createdEventIdentifiers {
            calendar.removeExternally(id: id)
        }

        let entry = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
        let hit = viewModel.hit(forHistoryEntry: entry)

        XCTAssertTrue(hit.members.isEmpty, "事件都没了，成员自然是空的")
        XCTAssertNil(hit.focusedEvent, "空成员时不该崩，也不该编出一个代表事件")
        XCTAssertFalse(viewModel.deleteSearchHit(hit), "没有可删的目标时应如实返回 false")
        XCTAssertNotEqual(viewModel.resultType, .warning, "空目标不是失败")
    }

    func testDeletionNeverTouchesSameNamedEventInAnotherCalendar() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)

        var created: [String] = []
        for calendarId in ["local-default", "outlook-default"] {
            let result = try await calendar.createSingleEvent(
                title: "同名会议",
                date: day,
                calendarId: calendarId,
                detail: nil
            )
            created.append(try XCTUnwrap(result.landed.first?.eventId))
        }
        XCTAssertEqual(events(calendar).count, 2)

        let localId = created[0]
        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: localId, on: day))
        XCTAssertTrue(viewModel.deleteSearchHit(hit))

        let remaining = events(calendar)
        XCTAssertEqual(remaining.count, 1, "只该删掉本地日历那一条")
        XCTAssertEqual(remaining.first?.calendarId, "outlook-default", "Outlook 里那条必须留着")
    }

    func testHistoryPanelDeleteDoesNotReachIntoAnotherCalendar() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)

        var created: [String] = []
        for calendarId in ["local-default", "outlook-default"] {
            viewModel.title = "历史同名"
            viewModel.baseDate = day
            viewModel.scheduleMode = .single
            viewModel.selectedCalendarIdentifier = calendarId
            viewModel.updateReviewDates()
            await viewModel.createReviewSchedule()
            let entry = try XCTUnwrap(
                viewModel.historyEntries.first { $0.liveEventIdentifiers.count == 1 }
            )
            created.append(try XCTUnwrap(entry.liveEventIdentifiers.first))
        }
        XCTAssertEqual(events(calendar).count, 2)

        let entries = viewModel.historyEntries
        let localEntry = try XCTUnwrap(
            entries.first { $0.liveEventIdentifiers.contains(created[0]) }
        )

        viewModel.deleteHistoryEntry(localEntry, members: localEntry.createdEventIdentifiers)

        let remaining = events(calendar)
        XCTAssertEqual(remaining.count, 1, "只该删掉这条记录自己的事件")
        XCTAssertEqual(
            remaining.first?.calendarId,
            "outlook-default",
            "另一条同名单次日程必须留着"
        )
    }

    func testUndoRemovesEveryEventItJustWrote() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let defaults = freshDefaults()
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "撤销三条"
        session.baseDate = date(2026, 11, 1)
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()
        XCTAssertEqual(events(calendar).count, 3)

        await session.undo()

        XCTAssertTrue(
            events(calendar).isEmpty,
            "撤销应把刚创建的三条全部删掉"
        )
        XCTAssertTrue(history.load().isEmpty, "撤销后不该留下指向已删事件的记录")
    }
}
