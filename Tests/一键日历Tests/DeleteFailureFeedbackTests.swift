import XCTest
@testable import 一键日历

@MainActor
final class DeleteFailureFeedbackTests: XCTestCase {
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

    func testFailedDeleteSurfacesAVisibleMessage() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let batch = try await makeSeries(viewModel, marker: "删不掉要提示-\(UUID().uuidString.prefix(6))")
        let victim = try XCTUnwrap(batch.createdEventIdentifiers.first)

        calendar.deleteShouldFailForTest = [victim]
        viewModel.deleteSearchHitMembers(ids: [victim])

        XCTAssertNotNil(
            viewModel.resultMessage,
            "删除失败时必须给用户可见提示，否则会以为已经删掉了"
        )
        XCTAssertEqual(viewModel.resultType, .warning)
    }

    func testRetrySucceedsOnceCalendarRecovers() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "重试能成功-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let victim = try XCTUnwrap(batch.createdEventIdentifiers.first)

        calendar.deleteShouldFailForTest = [victim]
        let first = viewModel.deleteSearchHitMembers(ids: [victim])
        XCTAssertEqual(first.deletedCount, 0)
        XCTAssertEqual(
            viewModel.historyEntries.first?.createdEventIdentifiers.count,
            3,
            "第一次删不掉时三条都必须留着"
        )

        calendar.deleteShouldFailForTest = []
        let second = viewModel.deleteSearchHitMembers(ids: [victim])

        XCTAssertEqual(second.deletedCount, 1, "重试时日历恢复后应能删掉")
        XCTAssertEqual(
            viewModel.historyEntries.first?.createdEventIdentifiers.count,
            2,
            "重试成功后只该少掉那一条"
        )
    }

    func testStuckIdentifierStaysDeletableAcrossAttempts() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "三条只留一条-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers
        let stuck = ids[1]

        calendar.deleteShouldFailForTest = [stuck]
        viewModel.deleteSearchHitMembers(ids: ids)

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(remaining.createdEventIdentifiers, [stuck])
        let hit = viewModel.hit(forHistoryEntry: remaining)
        XCTAssertEqual(hit.members.count, 1, "只剩删不掉的那条还能被解析出来")
        XCTAssertEqual(hit.members.first?.id, stuck)
    }
}
