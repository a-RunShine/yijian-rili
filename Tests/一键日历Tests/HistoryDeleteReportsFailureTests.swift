import XCTest
@testable import 一键日历

@MainActor
final class HistoryDeleteReportsFailureTests: XCTestCase {
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

    func testHistoryDeleteKeepsRecordWhenCalendarRefuses() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "日历拒绝时保留记录-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)

        calendar.deleteShouldFailForTest = Set(batch.createdEventIdentifiers)
        viewModel.deleteHistoryEntry(batch, members: batch.createdEventIdentifiers)

        XCTAssertTrue(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "日历一条都没删掉时，历史记录必须保留，否则用户既看不到也删不掉"
        )
    }

    func testHistoryDeleteSurfacesFailureMessage() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "日历拒绝要提示-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)

        calendar.deleteShouldFailForTest = Set(batch.createdEventIdentifiers)
        viewModel.deleteHistoryEntry(batch, members: batch.createdEventIdentifiers)

        XCTAssertNotNil(viewModel.resultMessage, "日历拒绝删除时必须告知用户")
        XCTAssertEqual(viewModel.resultType, .warning)
    }

    func testHistoryDeletePrunesOnlyDeletedMembers() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "只删掉两条-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers
        let stuck = ids[1]

        calendar.deleteShouldFailForTest = [stuck]
        viewModel.deleteHistoryEntry(batch, members: ids)

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(
            remaining.liveEventIdentifiers,
            [stuck],
            "只有删不掉的那条该留在记录里"
        )
        XCTAssertEqual(
            remaining.createdEventIdentifiers.count,
            remaining.reviewDates.count,
            "记录里的槽位数量必须与复习日数量一致"
        )
    }

    func testNeverKeepsAnIdentifierThatWasDeleted() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "删掉的必须消失-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers

        viewModel.deleteHistoryEntry(batch, members: ids)

        XCTAssertFalse(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "全部删成功后记录必须消失，不能留下空壳"
        )
    }

    func testRetryAfterFailureSucceedsAndClearsRecord() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "重试后彻底删除-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers

        calendar.deleteShouldFailForTest = Set(ids)
        viewModel.deleteHistoryEntry(batch, members: ids)
        XCTAssertTrue(viewModel.historyEntries.contains { $0.id == batch.id })

        calendar.deleteShouldFailForTest = []
        viewModel.deleteHistoryEntry(batch, members: ids)

        XCTAssertFalse(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "重试成功后记录应彻底消失"
        )
    }
}
