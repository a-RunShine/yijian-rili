import XCTest
@testable import 一键日历

@MainActor
final class DeleteEntryPointParityTests: XCTestCase {
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

    func testThirdMemberStaysRecognizableAfterDeletingFirstTwo() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "删两条留一条-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers

        let first = try XCTUnwrap(viewModel.hit(forHistoryEntry: batch).members.first)
        viewModel.deleteSearchHitMembers(ids: [first.id])

        let afterFirst = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
        let second = try XCTUnwrap(viewModel.hit(forHistoryEntry: afterFirst).members.first)
        viewModel.deleteSearchHitMembers(ids: [second.id])

        let afterSecond = try XCTUnwrap(
            viewModel.historyEntries.first { $0.id == batch.id },
            "删掉两条之后记录不该整个消失"
        )
        XCTAssertEqual(
            afterSecond.liveEventIdentifiers.count,
            1,
            "应只剩一个成员"
        )

        let survivorId = try XCTUnwrap(afterSecond.liveEventIdentifiers.first)
        XCTAssertTrue(
            viewModel.canMarkOccurrence(eventId: survivorId),
            "剩下的成员仍应被识别为复习系列成员"
        )

        let survivorHit = viewModel.hit(forHistoryEntry: afterSecond)
        XCTAssertEqual(survivorHit.members.count, 1)
        XCTAssertEqual(survivorHit.members.first?.id, survivorId)

        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: survivorId, on: date(2026, 11, 19)))
        XCTAssertTrue(viewModel.deleteSearchHit(hit))
        XCTAssertTrue(events(calendar).isEmpty, "三条删完日历应清空")
        XCTAssertFalse(
            viewModel.historyEntries.contains { $0.id == batch.id },
            "三条删完记录应消失"
        )
    }

    func testMainScreenAndHistoryPanelProduceTheSameResult() async throws {
        for viaHistoryPanel in [false, true] {
            let calendar = InMemoryCalendarService(grantAccessByDefault: true)
            let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
            let marker = "入口一致-\(viaHistoryPanel ? "历史" : "主界面")-\(UUID().uuidString.prefix(6))"
            let batch = try await makeSeries(viewModel, marker: marker)
            let victim = try XCTUnwrap(batch.createdEventIdentifiers[1])

            if viaHistoryPanel {
                let entry = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
                viewModel.deleteHistoryEntry(entry, members: [victim])
            } else {
                let hit = try XCTUnwrap(
                    viewModel.projectedHit(forEventId: victim, on: date(2026, 10, 27))
                )
                viewModel.deleteSearchHit(hit)
            }

            let remaining = try XCTUnwrap(viewModel.historyEntries.first { $0.id == batch.id })
            XCTAssertEqual(
                remaining.liveEventIdentifiers.count,
                2,
                "入口为 \(viaHistoryPanel ? "历史面板" : "主界面") 时应恰好剩两条"
            )
            XCTAssertEqual(
                events(calendar).count,
                2,
                "入口为 \(viaHistoryPanel ? "历史面板" : "主界面") 时日历也应恰好剩两条"
            )
            XCTAssertNotEqual(viewModel.resultType, .warning, "成功时不该弹失败提示")
        }
    }

    func testAbsentMemberIsNotCountedAsFailureInBatchDelete() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let marker = "本来就不在批量-\(UUID().uuidString.prefix(6))"
        let batch = try await makeSeries(viewModel, marker: marker)
        let ids = batch.createdEventIdentifiers

        XCTAssertTrue(calendar.removeExternally(id: ids[1]))

        let outcome = viewModel.deleteSearchHitMembers(ids: ids)
        XCTAssertEqual(outcome.deletedCount, 2, "另两条应正常删掉")
        XCTAssertEqual(outcome.refusedCount, 0, "本来就不在的那条不算失败")
        XCTAssertNotEqual(viewModel.resultType, .warning, "不该弹失败提示")
        XCTAssertTrue(events(calendar).isEmpty)
    }
}
