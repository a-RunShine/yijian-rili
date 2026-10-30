import XCTest
@testable import 一键日历

@MainActor
final class CreateLandingDetailTests: XCTestCase {
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

    func testCreateResultCarriesAddressAndIdentifierForEachLandedEvent() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let base = date(2026, 10, 20)
        let result = try await calendar.createReviewEvents(
            title: "落地明细",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: nil,
            detail: nil
        )

        XCTAssertEqual(result.landed.count, 3)
        for landed in result.landed {
            XCTAssertTrue(landed.wasWritten)
            XCTAssertEqual(landed.address.title, "落地明细")
            XCTAssertNotNil(landed.eventId)
        }
        XCTAssertEqual(
            Set(result.landed.map(\.address.notesKey)),
            ["第1次复习", "第2次复习", "第3次复习"]
        )
    }

    func testTwoDifferentTitlesOnOneDayEachKeepTheirOwnIdentifier() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)
        let titles = ["上午的会", "下午的会"]

        for title in titles {
            viewModel.title = title
            viewModel.baseDate = day
            viewModel.scheduleMode = .single
            viewModel.updateReviewDates()
            await viewModel.createReviewSchedule()
        }

        var identifiers: [String] = []
        for title in titles {
            let entry = try XCTUnwrap(viewModel.historyEntries.first { $0.title == title })
            XCTAssertEqual(entry.liveEventIdentifiers.count, 1)
            identifiers.append(try XCTUnwrap(entry.liveEventIdentifiers.first))
        }
        XCTAssertNotEqual(
            identifiers[0],
            identifiers[1],
            "同一天两条不同日程各自拿到自己的标识，不能因为同日就配错"
        )

        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: identifiers[0], on: day))
        XCTAssertTrue(viewModel.deleteSearchHit(hit))

        XCTAssertNil(calendar.event(withId: identifiers[0]))
        XCTAssertNotNil(
            calendar.event(withId: identifiers[1]),
            "删掉上午的会不该影响下午的会"
        )
        XCTAssertNotNil(
            viewModel.historyEntries.first { $0.title == "下午的会" },
            "另一条记录必须还在"
        )
    }

    func testDuplicateCreateStillWarnsAndWritesUnderSameRulesAsBefore() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let day = date(2026, 10, 20)

        for _ in 0..<2 {
            viewModel.title = "同名单次"
            viewModel.baseDate = day
            viewModel.scheduleMode = .single
            viewModel.updateReviewDates()
            await viewModel.createReviewSchedule()
        }

        XCTAssertEqual(
            viewModel.resultType,
            .warning,
            "同名同日应给出重复警告，这是 ADR 0005 的规定"
        )
        XCTAssertEqual(
            calendar.fetchEvents(on: day).count,
            2,
            "重复不阻止创建，两条都写进日历"
        )
        XCTAssertEqual(
            viewModel.historyEntries.filter { $0.title == "同名单次" }.count,
            1,
            "重复项不新建记录，保持原有行为"
        )
    }

    func testConsecutiveCreationsDoNotClobberEarlierIdentifiers() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())

        viewModel.title = "第一次"
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let first = try XCTUnwrap(viewModel.historyEntries.first { $0.title == "第一次" })
        let firstIds = first.liveEventIdentifiers
        XCTAssertEqual(firstIds.count, 3)

        viewModel.title = "第二次"
        viewModel.baseDate = date(2026, 11, 1)
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let reloaded = try XCTUnwrap(viewModel.historyEntries.first { $0.id == first.id })
        XCTAssertEqual(
            reloaded.liveEventIdentifiers,
            firstIds,
            "第二次创建不该破坏第一次记录里的标识"
        )
        for id in firstIds {
            XCTAssertNotNil(calendar.event(withId: id), "第一条系列应仍在日历里")
        }
    }
}
