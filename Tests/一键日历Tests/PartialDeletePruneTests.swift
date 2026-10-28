import XCTest
@testable import 一键日历

@MainActor
final class PartialDeletePruneTests: XCTestCase {
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

    func testPruneOnlyRemovesIdsThatCalendarActuallyDeleted() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "部分失败-\(UUID().uuidString.prefix(6))"
        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let entries = viewModel.historyEntries

        let batch = try XCTUnwrap(entries.first)
        let ids = batch.createdEventIdentifiers
        XCTAssertEqual(ids.count, 3)

        calendar.deleteShouldFailForTest = [ids[1]]
        let outcome = viewModel.deleteSearchHitMembers(ids: ids)

        XCTAssertEqual(outcome.deletedCount, 2)
        XCTAssertEqual(outcome.missingCount, 1)

        let remaining = try XCTUnwrap(viewModel.historyEntries.first)
        XCTAssertEqual(
            remaining.createdEventIdentifiers,
            [ids[1]],
            "只有真正删掉的事件才该从历史里修剪，删失败的那条必须留着，否则它就成了无法标记的孤儿"
        )
    }
}
