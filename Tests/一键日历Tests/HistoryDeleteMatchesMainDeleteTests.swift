import XCTest
@testable import 一键日历

@MainActor
final class HistoryDeleteMatchesMainDeleteTests: XCTestCase {
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

    private func makeBatch(
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
        calendar.fetchEvents(from: date(2026, 10, 1), to: date(2027, 1, 1))
    }

    func testHistoryEntryOfSeriesExposesAllMembersAsSeriesHit() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "历史转系列-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, marker: marker)

        let hit = viewModel.hit(forHistoryEntry: batch)

        XCTAssertTrue(hit.isSeries, "多条复习日的记录应转成系列，交给同一套选择性删除流程")
        XCTAssertEqual(hit.members.count, 3)
        XCTAssertTrue(hit.asksForDeleteScope, "多成员时应弹选择列表")
    }

    func testHistoryEntryOfSingleDayIsNotSelective() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "历史单条-\(UUID().uuidString.prefix(6))"
        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .single
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()
        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))

        let hit = viewModel.hit(forHistoryEntry: batch)

        XCTAssertFalse(hit.isSeries)
        XCTAssertEqual(hit.members.count, 1)
        XCTAssertFalse(hit.asksForDeleteScope, "单条日期的记录应走和主界面一样的确认弹窗")
    }

    func testDeletingWholeHistoryEntryRemovesCalendarEventsAndRecord() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "整条删除-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, marker: marker)
        let memberId = try XCTUnwrap(batch.createdEventIdentifiers.first)
        XCTAssertTrue(events(calendar).contains { $0.id == memberId })

        viewModel.deleteHistoryEntry(batch, members: batch.createdEventIdentifiers)

        XCTAssertFalse(viewModel.historyEntries.contains { $0.id == batch.id })
        XCTAssertFalse(
            events(calendar).contains { $0.id == memberId },
            "删除历史条目时所有成员日程应一并删除，不留孤儿"
        )
    }

    func testDeletingHistoryEntryClearsWeeklyEntryAndStatus() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "连带清理-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, marker: marker)
        let memberId = try XCTUnwrap(batch.createdEventIdentifiers.first)
        viewModel.setOccurrenceStatus(eventId: memberId, status: .done)
        XCTAssertTrue(viewModel.weeklyReviewViewModel.weeklyEntries.contains { $0.id == batch.id })

        viewModel.deleteHistoryEntry(batch, members: batch.createdEventIdentifiers)

        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains { $0.id == batch.id },
            "历史删除后周回顾仍留着这条，两处数据不一致"
        )
        XCTAssertEqual(
            viewModel.occurrenceStatus(for: memberId),
            .unmarked,
            "历史条目删掉后其完成标记应一并清理"
        )
    }

    func testDeleteFlowRequestsSeriesSelectionForMultiMemberHistoryEntry() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "历史弹系列-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, marker: marker)
        let flow = SearchHitDeleteFlow()

        flow.requestDeletingHistory(batch, in: viewModel)

        XCTAssertNotNil(
            viewModel.seriesPendingDelete,
            "多成员时历史删除应复用主界面的系列删除弹窗"
        )
        XCTAssertTrue(viewModel.historyEntries.contains { $0.id == batch.id })
    }

    func testDeleteFlowUsesPlainConfirmationForSingleMemberHistoryEntry() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "历史单确认-\(UUID().uuidString.prefix(6))"
        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .single
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()
        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let flow = SearchHitDeleteFlow()

        flow.requestDeletingHistory(batch, in: viewModel)

        XCTAssertNotNil(
            flow.hitPendingDelete,
            "单成员时历史删除应走和主界面一样的确认弹窗"
        )
        flow.cancel()
        XCTAssertTrue(viewModel.historyEntries.contains { $0.id == batch.id })
    }
}
