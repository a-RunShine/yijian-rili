import XCTest
@testable import 一键日历

@MainActor
final class EventAddressDeleteTests: XCTestCase {
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

    func testDeletingThirdMemberSurvivesIdentifierReassignment() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "重分配后逐条删-\(UUID().uuidString.prefix(6))"
        let day = date(2026, 10, 20)
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers
        XCTAssertEqual(ids.count, 3)

        let first = try XCTUnwrap(viewModel.projectedHit(forEventId: ids[0], on: day))
        XCTAssertTrue(viewModel.deleteSearchHit(first), "第 1 条应删除成功")

        _ = calendar.reassignAllEventIdentifiersForTesting()

        for index in 1..<3 {
            let remaining = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
            let memberId = try XCTUnwrap(
                remaining.createdEventIdentifiers.first,
                "第 \(index + 1) 条：记录里应还剩成员"
            )
            let hit = try XCTUnwrap(
                viewModel.projectedHit(forEventId: memberId, on: day)
                    ?? viewModel.hit(forHistoryEntry: remaining),
                "第 \(index + 1) 条：应能解析出待删目标"
            )
            XCTAssertTrue(
                viewModel.deleteSearchHit(hit),
                "第 \(index + 1) 条：id 被重分配之后仍应删除成功"
            )
            XCTAssertNotEqual(
                viewModel.resultType,
                .warning,
                "第 \(index + 1) 条：成功时不该弹出失败提示"
            )
        }

        XCTAssertFalse(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "三条都删掉后记录应消失"
        )
        XCTAssertTrue(
            calendar.fetchEvents(
                from: date(2026, 10, 1),
                to: date(2026, 12, 1)
            ).isEmpty,
            "三条都删掉后日历里不该还有残留"
        )
    }

    func testDeletingEventThatIsAlreadyGoneReportsNoFailure() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)
        let batch = try await makeSeries(
            viewModel,
            marker: "本来就不在-\(UUID().uuidString.prefix(6))"
        )
        let victim = try XCTUnwrap(batch.createdEventIdentifiers.first)
        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: victim, on: day))

        XCTAssertTrue(calendar.deleteEvent(id: victim), "先在外部删掉这条")

        XCTAssertTrue(
            viewModel.deleteSearchHit(hit),
            "日历里本来就没有这条时，不应算作失败"
        )
        XCTAssertNotEqual(
            viewModel.resultType,
            .warning,
            "「本来就不在」不该弹失败提示"
        )
        XCTAssertFalse(
            viewModel.historyEntries.first?.createdEventIdentifiers.contains(victim) ?? true,
            "记录里那一条也该一并清掉"
        )
    }

    func testDeletingFromReadOnlyCalendarReportsTheRealReason() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)
        let batch = try await makeSeries(
            viewModel,
            marker: "只读日历-\(UUID().uuidString.prefix(6))"
        )
        let victim = try XCTUnwrap(batch.createdEventIdentifiers.first)
        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: victim, on: day))

        calendar.readOnlyCalendarIds = try XCTUnwrap(
            Set(calendar.fetchEvents(from: day, to: date(2026, 12, 1)).compactMap(\.calendarId))
        )

        XCTAssertFalse(viewModel.deleteSearchHit(hit), "只读日历里删不掉，应如实报告")
        XCTAssertEqual(viewModel.resultType, .warning)
        XCTAssertEqual(
            viewModel.resultMessage,
            NSLocalizedString("delete_failed_read_only", comment: ""),
            "应说清是日历不让改，而不是笼统的失败"
        )
    }

    func testDeletingWithoutAuthorizationReportsPermissionProblem() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)
        let batch = try await makeSeries(
            viewModel,
            marker: "没授权-\(UUID().uuidString.prefix(6))"
        )
        let victim = try XCTUnwrap(batch.createdEventIdentifiers.first)
        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: victim, on: day))

        calendar.setAuthorizationStatusForTesting(.denied)

        XCTAssertFalse(viewModel.deleteSearchHit(hit))
        XCTAssertEqual(viewModel.resultType, .warning)
        XCTAssertEqual(
            viewModel.resultMessage,
            NSLocalizedString("delete_failed_no_access", comment: ""),
            "没授权时应说清需要授权，而不是说删除失败"
        )
    }
}
