import XCTest
@testable import 一键日历

@MainActor
final class MainScreenDeleteSequenceTests: XCTestCase {
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

    func testDeletingEachOfThreeSeriesMembersOneByOne() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "逐个删除-\(UUID().uuidString.prefix(6))"
        let day = date(2026, 10, 20)

        viewModel.title = marker
        viewModel.baseDate = day
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        XCTAssertEqual(ids.count, 3)

        for (index, id) in ids.enumerated() {
            let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: id, on: day))
            let deleted = viewModel.deleteSearchHit(hit)
            XCTAssertTrue(
                deleted,
                "主界面删除第 \(index + 1) 条（id=\(id.suffix(12))）应成功"
            )
            let still = viewModel.historyEntries.first { $0.id == batch.id }
            XCTAssertFalse(
                still?.liveEventIdentifiers.contains(id) ?? false,
                "第 \(index + 1) 条删掉后，记录里不该还留着它的 id"
            )
        }

        XCTAssertFalse(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "三条都删掉后记录应消失"
        )
    }

    func testDeletingTwoAtOnceSucceeds() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "一次删两条-\(UUID().uuidString.prefix(6))"

        viewModel.title = marker
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        let two = Array(ids.prefix(2))

        let outcome = viewModel.deleteSearchHitMembers(ids: two)

        XCTAssertEqual(outcome.deletedCount, 2)
        XCTAssertEqual(outcome.refusedCount, 0)
        let remaining = viewModel.historyEntries.first { $0.id == batch.id }
        XCTAssertEqual(remaining?.liveEventIdentifiers, [ids[2]])
    }
}
