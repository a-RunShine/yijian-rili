import XCTest
@testable import 一键日历

@MainActor
final class HistoryDeleteDropsCalendarTest: XCTestCase {
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
        calendar: InMemoryCalendarService,
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

    func testDeleteRecordOnlyKeepsCalendarEvents() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "只删记录-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, calendar: calendar, marker: marker)
        let memberId = try XCTUnwrap(batch.createdEventIdentifiers.first)

        viewModel.commitHistoryDelete(batch, scope: .recordOnly)

        XCTAssertFalse(viewModel.historyEntries.contains { $0.id == batch.id })
        XCTAssertTrue(
            events(calendar).contains { $0.id == memberId },
            "选择「只删记录」时日历日程应保留"
        )
    }

    func testDeleteRecordAndEventsRemovesCalendarEvents() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "连日程一起删-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, calendar: calendar, marker: marker)
        let memberId = try XCTUnwrap(batch.createdEventIdentifiers.first)
        XCTAssertTrue(events(calendar).contains { $0.id == memberId })

        viewModel.commitHistoryDelete(batch, scope: .eventsToo)

        XCTAssertFalse(viewModel.historyEntries.contains { $0.id == batch.id })
        XCTAssertFalse(
            events(calendar).contains { $0.id == memberId },
            "选择「连同日程一起删」后日历里不应再留着这条"
        )
    }

    func testRequestsChoiceBeforeDeletingSeries() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "先弹列表-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, calendar: calendar, marker: marker)

        viewModel.requestHistoryDelete(batch)

        XCTAssertNotNil(
            viewModel.historyPendingDelete,
            "多成员系列在历史里删除时应先弹出范围选择，而不是直接删掉整条记录"
        )
        XCTAssertTrue(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "只请求删除时不应改动任何数据"
        )
    }

    func testCancelLeavesEverythingUntouched() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "取消删除-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, calendar: calendar, marker: marker)
        let memberId = try XCTUnwrap(batch.createdEventIdentifiers.first)

        viewModel.requestHistoryDelete(batch)
        viewModel.cancelHistoryDelete()

        XCTAssertNil(viewModel.historyPendingDelete)
        XCTAssertTrue(viewModel.historyEntries.contains { $0.id == batch.id })
        XCTAssertTrue(events(calendar).contains { $0.id == memberId })
    }

    func testDeletingHistoryEntryAlsoRemovesWeeklyEntry() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "历史删除同步周回顾-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, calendar: calendar, marker: marker)
        XCTAssertTrue(viewModel.weeklyReviewViewModel.weeklyEntries.contains { $0.id == batch.id })

        viewModel.commitHistoryDelete(batch, scope: .recordOnly)

        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains { $0.id == batch.id },
            "历史删除后周回顾仍留着这条，两处数据不一致"
        )
    }

    func testDeletingHistoryEntryClearsOccurrenceStatus() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "历史删除清状态-\(UUID().uuidString.prefix(6))"
        let batch = try await makeBatch(viewModel, calendar: calendar, marker: marker)
        let memberId = try XCTUnwrap(batch.createdEventIdentifiers.first)
        viewModel.setOccurrenceStatus(eventId: memberId, status: .done)
        XCTAssertEqual(viewModel.occurrenceStatus(for: memberId), .done)

        viewModel.commitHistoryDelete(batch, scope: .recordOnly)

        XCTAssertEqual(
            viewModel.occurrenceStatus(for: memberId),
            .unmarked,
            "历史条目删掉后，其完成标记应一并清理，否则永久孤儿"
        )
    }
}
