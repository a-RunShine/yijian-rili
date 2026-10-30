import XCTest
@testable import 一键日历

@MainActor
final class SeriesDeleteSingleMemberTests: XCTestCase {
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

    private func events(_ calendar: InMemoryCalendarService) -> [CalendarEventInfo] {
        calendar.fetchEvents(from: date(2026, 10, 1), to: date(2027, 1, 1))
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

    func testDeletingOneMemberFromHistorySeriesRemovesExactlyThatOne() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "只删一条-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        XCTAssertEqual(events(calendar).count, 3)

        let hit = viewModel.hit(forHistoryEntry: batch)
        let victim = try XCTUnwrap(hit.members.first)

        let outcome = viewModel.deleteSearchHitMembers(ids: [victim.id])

        XCTAssertEqual(outcome.deletedCount, 1, "选中一条时应只删这一条")
        XCTAssertEqual(events(calendar).count, 2, "另外两条必须留着")
        XCTAssertFalse(events(calendar).contains { $0.id == victim.id })
    }

    func testDeletingOneMemberKeepsSeriesRecognizable() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "删一条仍可标记-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let hit = viewModel.hit(forHistoryEntry: batch)
        let victim = try XCTUnwrap(hit.members.first)
        let survivor = try XCTUnwrap(hit.members.last)

        viewModel.deleteSearchHitMembers(ids: [victim.id])

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(remaining.liveEventIdentifiers.count, 2)
        XCTAssertTrue(
            viewModel.canMarkOccurrence(eventId: survivor.id),
            "剩下的成员应仍能被识别为复习系列"
        )
    }

    func testDeletingOneMemberWithDuplicateTitleSeriesDeletesOnlyOne() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "同名重复-\\(UUID().uuidString.prefix(6))"

        let first = try await makeSeries(viewModel, marker: marker)
        let beforeSecond = events(calendar).count
        let second = try await makeSeries(viewModel, marker: marker)
        let afterSecond = events(calendar).count


        let hit = viewModel.hit(forHistoryEntry: second)
        let victim = try XCTUnwrap(hit.members.first)
        let totalBefore = afterSecond

        let outcome = viewModel.deleteSearchHitMembers(ids: [victim.id])

        let totalAfter = events(calendar).count
        XCTAssertEqual(totalAfter, totalBefore - 1, "只勾一条时日历事件应只少一条")
    }

    func testPruneUsesActuallyDeletedIdsNotRequestedIds() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "修剪只认删成功的-\\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let hit = viewModel.hit(forHistoryEntry: batch)

        let ghost = "does-not-exist-\\(UUID().uuidString.prefix(6))"
        let victim = try XCTUnwrap(hit.members.first)
        let survivor = try XCTUnwrap(hit.members.last)
        let before = events(calendar).count

        let outcome = viewModel.deleteSearchHitMembers(ids: [victim.id, ghost])

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(
            remaining.liveEventIdentifiers.count,
            before - 1,
            "历史只应修剪真正删掉的事件，未删成功的不应被记录成已删除"
        )
    }

    func testHistoryKeepsIdWhoseCalendarDeleteFailed() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "删失败不该记成已删-\\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let hit = viewModel.hit(forHistoryEntry: batch)
        let victim = try XCTUnwrap(hit.members.first)

        calendar.eventsUnreadable = true
        let outcome = viewModel.deleteSearchHitMembers(ids: [victim.id])
        calendar.eventsUnreadable = false

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(outcome.deletedCount, 0, "日历删不掉时不应报告已删")
        XCTAssertEqual(
            remaining.liveEventIdentifiers.count,
            3,
            "日历没删成功时，历史不应把这个 id 当作已删除修剪掉"
        )
    }
}
