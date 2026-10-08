import XCTest
@testable import 一键日历

/// 日历 seam（`InMemoryCalendarService`）行为测试；对齐 Windows InMemory 能力集合。
@MainActor
final class InMemoryCalendarServiceTests: XCTestCase {
    func testHasCloudCalendarAndLocalSortsLast() {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        XCTAssertTrue(calendar.hasCloudCalendar)
        XCTAssertEqual(calendar.availableCalendars.last?.sourceKind, .local)
        XCTAssertEqual(calendar.availableCalendars.first?.sourceKind, .cloud)
    }

    func testRequestAccessFromNotDetermined() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: false)
        XCTAssertEqual(calendar.authorizationStatus, .notDetermined)
        XCTAssertTrue(calendar.availableCalendars.isEmpty)
        let granted = await calendar.requestAccess()
        XCTAssertTrue(granted)
        XCTAssertEqual(calendar.authorizationStatus, .fullAccess)
        XCTAssertFalse(calendar.availableCalendars.isEmpty)
    }

    func testCreateReviewScheduleWritesEvents() async throws {
        let calendar = InMemoryCalendarService()
        let base = date(2026, 1, 31)
        let result = try await calendar.createReviewEvents(
            title: "Swift",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: nil
        )
        XCTAssertEqual(result.created.count, 3)
        XCTAssertTrue(result.duplicates.isEmpty)
        XCTAssertTrue(result.failed.isEmpty)
        XCTAssertEqual(calendar.lastCreatedEventIdentifiers.count, 3)

        let day = try await calendar.createReviewEvents(
            title: "Swift",
            baseDate: base,
            intervals: [3, 7, 30],
            calendarId: nil
        )
        XCTAssertEqual(day.duplicates.count, 3)
        XCTAssertEqual(day.created.count, 3)
    }

    func testCreateSingleAndUndo() async throws {
        let calendar = InMemoryCalendarService()
        let day = date(2026, 3, 1)
        let created = try await calendar.createSingleEvent(title: "Meeting", date: day, calendarId: nil)
        XCTAssertEqual(created.created.count, 1)
        XCTAssertEqual(calendar.fetchEvents(on: day).count, 1)

        let undo = await calendar.undoLastCreation()
        XCTAssertTrue(undo.success)
        XCTAssertEqual(undo.deletedCount, 1)
        XCTAssertTrue(calendar.fetchEvents(on: day).isEmpty)
    }

    func testSearchAndDeleteById() async throws {
        let calendar = InMemoryCalendarService()
        _ = try await calendar.createSingleEvent(title: "Alpha Beta", date: Date(), calendarId: nil)
        let hits = calendar.searchEvents(query: "alpha", daysAhead: 90)
        XCTAssertEqual(hits.count, 1)
        XCTAssertTrue(calendar.deleteEvent(id: hits[0].id))
        XCTAssertTrue(calendar.searchEvents(query: "alpha", daysAhead: 90).isEmpty)
    }

    func testCreateWithoutAccessThrows() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: false)
        do {
            _ = try await calendar.createSingleEvent(title: "X", date: Date(), calendarId: nil)
            XCTFail("expected accessDenied")
        } catch let error as CalendarError {
            XCTAssertEqual(error, .accessDenied)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testCreateReviewRejectsInvalidIntervals() async {
        let calendar = InMemoryCalendarService()
        do {
            _ = try await calendar.createReviewEvents(
                title: "X",
                baseDate: Date(),
                intervals: [30, 7, 3],
                calendarId: nil
            )
            XCTFail("expected invalidIntervals")
        } catch let error as CalendarError {
            XCTAssertEqual(error, .invalidIntervals)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        return Calendar.current.date(from: components)!
    }
}

@MainActor
final class ReviewViewModelCalendarInjectionTests: XCTestCase {
    func testCreateReviewScheduleSucceedsWithInMemoryCalendar() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "注入日历 seam"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()

        await viewModel.createReviewSchedule()

        XCTAssertEqual(viewModel.resultType, .success)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertEqual(calendar.lastCreatedEventIdentifiers.count, 3)
        XCTAssertFalse(viewModel.historyEntries.isEmpty)
        XCTAssertEqual(viewModel.historyEntries.first?.title, "注入日历 seam")
    }

    func testDefaultSegmentIsCreate() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true))
        XCTAssertEqual(viewModel.selectedSegment, .create)
    }

    func testDetailBindingRoundsTripToSession() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.detail = "  课堂补充  "
        viewModel.title = "详情绑定"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()

        XCTAssertEqual(viewModel.session.detail, "  课堂补充  ")

        await viewModel.createReviewSchedule()

        XCTAssertEqual(viewModel.resultType, .success)
        XCTAssertEqual(viewModel.detail, "")
        XCTAssertEqual(viewModel.session.detail, "")
        XCTAssertEqual(viewModel.historyEntries.first?.sharedDetail, "课堂补充")
        XCTAssertFalse(viewModel.todayCreatedEntries.isEmpty)
        XCTAssertEqual(viewModel.todayCreatedEntries.first?.title, "详情绑定")
    }

    func testUpdateSharedDetailViaFacade() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "系列编辑"
        viewModel.detail = "初始"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        guard let entry = viewModel.historyEntries.first else {
            return XCTFail("expected history entry")
        }
        XCTAssertFalse(entry.createdEventIdentifiers.isEmpty)

        let outcome = viewModel.updateSharedDetail(for: entry, detail: "  修订  ")
        XCTAssertEqual(outcome, .updated(updated: 3, missing: 0))
        XCTAssertEqual(viewModel.historyEntries.first?.sharedDetail, "修订")
        XCTAssertEqual(viewModel.resultType, .success)
    }

    func testSharedDetailUnavailableWhenNoIdentifiers() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true))
        let legacy = HistoryEntry(
            title: "旧记录",
            baseDate: date(2026, 1, 1),
            reviewDates: [date(2026, 1, 4)],
            creationDate: Date(),
            createdEventIdentifiers: []
        )
        let outcome = viewModel.updateSharedDetail(for: legacy, detail: "不应写入")
        XCTAssertEqual(outcome, .unavailable)
        XCTAssertEqual(viewModel.resultType, .warning)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        return Calendar.current.date(from: components)!
    }
}
