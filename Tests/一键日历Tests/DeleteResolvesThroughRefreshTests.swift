import XCTest
@testable import 一键日历

@MainActor
final class DeleteResolvesThroughRefreshTests: XCTestCase {
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

    func testFailedDeleteKeepsIdentifierSoItStaysMarkable() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "删不掉仍可标记-\(UUID().uuidString.prefix(6))"
        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        let victim = try XCTUnwrap(ids.first)

        calendar.deleteShouldFailForTest = [victim]
        let outcome = viewModel.deleteSearchHitMembers(ids: [victim])

        XCTAssertEqual(outcome.deletedCount, 0)
        XCTAssertEqual(outcome.refusedCount, 1)

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(remaining.liveEventIdentifiers, ids, "删不掉时历史必须原样保留")
        XCTAssertTrue(
            viewModel.canMarkOccurrence(eventId: victim),
            "删不掉的事件仍应能被识别为复习系列，否则用户既删不掉也标记不了"
        )
    }

    func testPartialFailureKeepsOnlyTheUndelatableIdentifier() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "部分删不掉-\(UUID().uuidString.prefix(6))"
        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        let stuck = ids[1]

        calendar.deleteShouldFailForTest = [stuck]
        let outcome = viewModel.deleteSearchHitMembers(ids: ids)

        XCTAssertEqual(outcome.deletedCount, 2)
        XCTAssertEqual(outcome.refusedCount, 1)

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(
            remaining.liveEventIdentifiers,
            [stuck],
            "只剩删不掉的那条留在历史里，用户还能再试一次"
        )
    }
}
