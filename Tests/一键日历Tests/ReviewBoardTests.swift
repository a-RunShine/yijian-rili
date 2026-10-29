import XCTest
@testable import 一键日历

@MainActor
final class ReviewBoardTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let isolated = makeIsolatedDefaults()
        addTeardownBlock { isolated.cleanUp() }
        return isolated.defaults
    }
    func testSelectingADayNormalizesBaseDateAndShowsTheFirstOfThatMonth() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true), defaults: freshDefaults())

        viewModel.selectDay(dateTime(2026, 10, 20, 15, 30))

        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 20))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 10, 1))
    }

    func testDailyIntervalsFromOctober20PreviewTheFirstThreeReviews() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true), defaults: freshDefaults())
        viewModel.selectDay(date(2026, 1, 31))
        viewModel.applyPreset(.daily)

        viewModel.selectDay(date(2026, 10, 20))

        XCTAssertEqual(viewModel.reviewDates, [
            date(2026, 10, 23),
            date(2026, 10, 27),
            date(2026, 11, 19),
        ])
    }

    func testSingleSchedulePreviewIsOnlyTheBaseDate() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true), defaults: freshDefaults())
        viewModel.applyPreset(.daily)
        viewModel.selectDay(date(2026, 10, 20))

        viewModel.scheduleMode = .single

        XCTAssertEqual(viewModel.reviewDates, [date(2026, 10, 20)])
    }

    func testSelectingADayLoadsTheFortyTwoDayWindowOnceAndGroupsByDay() {
        let calendar = RangeQueryCalendar(events: [
            event(id: "before", title: "窗外", start: dateTime(2026, 9, 27, 10, 0), end: dateTime(2026, 9, 27, 11, 0), isAllDay: false),
            event(id: "first", title: "首格", start: date(2026, 9, 28), end: date(2026, 9, 29), isAllDay: true),
            event(id: "span", title: "跨天", start: dateTime(2026, 10, 1, 22, 0), end: dateTime(2026, 10, 3, 1, 0), isAllDay: false),
            event(id: "last", title: "末格", start: dateTime(2026, 11, 8, 10, 0), end: dateTime(2026, 11, 8, 11, 0), isAllDay: false),
            event(id: "after", title: "窗外后", start: date(2026, 11, 9), end: dateTime(2026, 11, 9, 1, 0), isAllDay: false),
        ])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        let daysBefore = calendar.dayFetches

        viewModel.selectDay(date(2026, 10, 20))

        XCTAssertEqual(calendar.dayFetches, daysBefore)
        XCTAssertEqual(calendar.rangeFetches.last?.start, date(2026, 9, 28))
        XCTAssertEqual(calendar.rangeFetches.last?.end, date(2026, 11, 9))
        let fetchesAfterSelect = calendar.rangeFetches.count
        viewModel.selectDay(date(2026, 10, 21))
        XCTAssertEqual(calendar.rangeFetches.count, fetchesAfterSelect)
        XCTAssertEqual(ids(on: date(2026, 9, 28), in: viewModel), ["first"])
        XCTAssertEqual(ids(on: date(2026, 10, 1), in: viewModel), ["span"])
        XCTAssertEqual(ids(on: date(2026, 10, 2), in: viewModel), ["span"])
        XCTAssertEqual(ids(on: date(2026, 10, 3), in: viewModel), ["span"])
        XCTAssertEqual(ids(on: date(2026, 11, 8), in: viewModel), ["last"])
        let loaded = Set(viewModel.eventsByDay.values.flatMap { $0.map(\.id) })
        XCTAssertFalse(loaded.contains("before"))
        XCTAssertFalse(loaded.contains("after"))
    }

    func testSelectingADayInsideTheVisibleMonthKeepsTheMonthAndWindowAndRecomputesThePreview() {
        let calendar = RangeQueryCalendar(events: [])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.applyPreset(.daily)
        viewModel.selectDay(date(2026, 10, 20))
        let rangesBefore = calendar.rangeFetches.count

        viewModel.selectDay(date(2026, 10, 21))

        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 21))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 10, 1))
        XCTAssertEqual(calendar.rangeFetches.count, rangesBefore)
        XCTAssertEqual(viewModel.reviewDates, [
            date(2026, 10, 24),
            date(2026, 10, 28),
            date(2026, 11, 20),
        ])
    }

    func testSelectingADayInsideTheVisibleMonthMatchesTheReselectionDrag() {
        let clicked = RangeQueryCalendar(events: [])
        let clickedModel = ReviewViewModel(calendar: clicked, defaults: freshDefaults())
        clickedModel.applyPreset(.daily)
        clickedModel.selectDay(date(2026, 10, 20))
        let clickedRangesBefore = clicked.rangeFetches.count

        let dragged = RangeQueryCalendar(events: [])
        let draggedModel = ReviewViewModel(calendar: dragged, defaults: freshDefaults())
        draggedModel.applyPreset(.daily)
        draggedModel.selectDay(date(2026, 10, 20))
        let draggedRangesBefore = dragged.rangeFetches.count

        clickedModel.selectDay(date(2026, 10, 23))
        draggedModel.moveSelection(to: date(2026, 10, 23))

        XCTAssertEqual(clickedModel.baseDate, draggedModel.baseDate)
        XCTAssertEqual(clickedModel.visibleMonth, draggedModel.visibleMonth)
        XCTAssertEqual(clickedModel.reviewDates, draggedModel.reviewDates)
        XCTAssertEqual(clicked.rangeFetches.count, clickedRangesBefore)
        XCTAssertEqual(dragged.rangeFetches.count, draggedRangesBefore)
        XCTAssertEqual(clickedModel.visibleMonth, date(2026, 10, 1))
    }

    func testSelectingADayOutsideTheVisibleMonthFollowsTheBaseDateAndLoadsTheWindow() {
        let calendar = RangeQueryCalendar(events: [
            event(id: "nov", title: "十一月", start: date(2026, 11, 30), end: date(2026, 12, 1), isAllDay: true),
            event(id: "dec", title: "十二月", start: date(2026, 12, 6), end: date(2026, 12, 7), isAllDay: true),
        ])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.applyPreset(.daily)
        viewModel.selectDay(date(2026, 10, 20))
        let rangesBefore = calendar.rangeFetches.count

        viewModel.selectDay(date(2026, 12, 3))

        XCTAssertEqual(viewModel.baseDate, date(2026, 12, 3))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 12, 1))
        XCTAssertEqual(calendar.rangeFetches.count, rangesBefore + 1)
        XCTAssertEqual(calendar.rangeFetches.last?.start, date(2026, 11, 30))
        XCTAssertEqual(calendar.rangeFetches.last?.end, date(2027, 1, 11))
        XCTAssertEqual(viewModel.reviewDates, [
            date(2026, 12, 6),
            date(2026, 12, 10),
            date(2027, 1, 2),
        ])
        XCTAssertEqual(ids(on: date(2026, 12, 6), in: viewModel), ["dec"])
    }

    func testShiftingMonthKeepsTheBaseDateAndPreview() {
        let calendar = RangeQueryCalendar(events: [
            event(id: "oct", title: "十月", start: date(2026, 10, 20), end: date(2026, 10, 21), isAllDay: true),
            event(id: "nov", title: "十一月", start: date(2026, 11, 19), end: date(2026, 11, 20), isAllDay: true),
        ])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.applyPreset(.daily)
        viewModel.selectDay(date(2026, 10, 20))
        let rangesBefore = calendar.rangeFetches.count

        viewModel.shiftVisibleMonth(by: 1)

        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 20))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 11, 1))
        XCTAssertEqual(viewModel.reviewDates, [
            date(2026, 10, 23),
            date(2026, 10, 27),
            date(2026, 11, 19),
        ])
        XCTAssertEqual(calendar.rangeFetches.count, rangesBefore + 1)
        XCTAssertEqual(calendar.rangeFetches.last?.start, date(2026, 10, 26))
        XCTAssertEqual(calendar.rangeFetches.last?.end, date(2026, 12, 7))
        XCTAssertEqual(ids(on: date(2026, 11, 19), in: viewModel), ["nov"])
        XCTAssertFalse(Set(viewModel.eventsByDay.values.flatMap { $0.map(\.id) }).contains("oct"))
    }

    func testShiftingMonthDoesNotRewriteTheBaseDateWhenTheDayNumberIsMissing() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true), defaults: freshDefaults())

        viewModel.selectDay(date(2026, 1, 31))
        viewModel.shiftVisibleMonth(by: 1)
        XCTAssertEqual(viewModel.baseDate, date(2026, 1, 31))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 2, 1))

        viewModel.selectDay(date(2024, 1, 31))
        viewModel.shiftVisibleMonth(by: 1)
        XCTAssertEqual(viewModel.baseDate, date(2024, 1, 31))
        XCTAssertEqual(viewModel.visibleMonth, date(2024, 2, 1))

        viewModel.selectDay(date(2026, 3, 31))
        viewModel.shiftVisibleMonth(by: -1)
        XCTAssertEqual(viewModel.baseDate, date(2026, 3, 31))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 2, 1))
    }

    func testMovingSelectionInsideTheVisibleWindowDoesNotFetchAgain() {
        let calendar = RangeQueryCalendar(events: [])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.applyPreset(.daily)
        viewModel.selectDay(date(2026, 10, 20))
        let rangesBefore = calendar.rangeFetches.count

        viewModel.moveSelection(to: date(2026, 10, 21))

        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 21))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 10, 1))
        XCTAssertEqual(calendar.rangeFetches.count, rangesBefore)
        XCTAssertEqual(viewModel.reviewDates, [
            date(2026, 10, 24),
            date(2026, 10, 28),
            date(2026, 11, 20),
        ])
    }

    func testGoToTodayRefreshesBaseDateVisibleMonthAndEvents() {
        let calendar = RangeQueryCalendar(events: [
            event(id: "may", title: "五月", start: date(2026, 5, 4), end: date(2026, 5, 5), isAllDay: true),
            event(id: "dec", title: "十二月", start: date(2026, 12, 1), end: date(2026, 12, 2), isAllDay: true),
        ])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.selectDay(date(2026, 1, 15))
        let rangesBefore = calendar.rangeFetches.count

        viewModel.goToToday(now: dateTime(2026, 5, 4, 9, 15))

        XCTAssertEqual(viewModel.baseDate, date(2026, 5, 4))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 5, 1))
        XCTAssertEqual(calendar.rangeFetches.count, rangesBefore + 1)
        XCTAssertEqual(ids(on: date(2026, 5, 4), in: viewModel), ["may"])
        XCTAssertFalse(Set(viewModel.eventsByDay.values.flatMap { $0.map(\.id) }).contains("dec"))
    }

    func testChoosingHistoryAlignsTheBoardToThatEntryBaseDate() {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true, events: [
            event(id: "march", title: "三月", start: date(2026, 3, 15), end: date(2026, 3, 16), isAllDay: true),
            event(id: "jan", title: "一月", start: date(2026, 1, 1), end: date(2026, 1, 2), isAllDay: true),
        ])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.customIntervalDraft = "2, 6, 18"
        viewModel.selectedSegment = .today
        viewModel.selectDay(date(2026, 10, 20))
        let entry = HistoryEntry(
            title: "旧复习",
            baseDate: dateTime(2026, 3, 15, 18, 30),
            reviewDates: [date(2026, 3, 18)],
            creationDate: date(2026, 3, 16),
            type: .review
        )

        viewModel.selectHistoryEntry(entry)

        XCTAssertEqual(viewModel.baseDate, date(2026, 3, 15))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 3, 1))
        XCTAssertEqual(viewModel.selectedSegment, .today)
        XCTAssertEqual(ids(on: date(2026, 3, 15), in: viewModel), ["march"])
        XCTAssertFalse(Set(viewModel.eventsByDay.values.flatMap { $0.map(\.id) }).contains("jan"))
        XCTAssertEqual(viewModel.customIntervalDraft, "2, 6, 18")
    }

    func testCustomIntervalDraftSurvivesDayMonthAndToday() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true), defaults: freshDefaults())
        viewModel.customIntervalDraft = "2, 6, 18"

        viewModel.selectDay(date(2026, 10, 20))
        viewModel.shiftVisibleMonth(by: 1)
        viewModel.goToToday(now: date(2026, 5, 4))

        XCTAssertEqual(viewModel.customIntervalDraft, "2, 6, 18")
    }

    func testBlankTitleDoesNotWrite() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.selectDay(date(2026, 10, 20))
        viewModel.title = " \n "

        await viewModel.createReviewSchedule()

        XCTAssertEqual(viewModel.resultType, .error)
        XCTAssertTrue(calendar.lastCreatedEventIdentifiers.isEmpty)
        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 20))
    }

    func testSubmitAppliesUncommittedIntervalDraftBeforeWriting() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.selectDay(date(2026, 10, 20))
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.title = "自定义节奏"
        viewModel.customIntervalDraft = "1, 2, 4"

        await viewModel.createReviewSchedule()

        XCTAssertEqual(viewModel.resultType, .success)
        XCTAssertEqual(viewModel.reviewIntervals, [1, 2, 4])
        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 20))
        XCTAssertEqual(viewModel.visibleMonth, date(2026, 10, 1))
        XCTAssertEqual(viewModel.customIntervalDraft, "1, 2, 4")
        XCTAssertEqual(titles(on: date(2026, 10, 21), in: viewModel), ["自定义节奏"])
        XCTAssertEqual(titles(on: date(2026, 10, 22), in: viewModel), ["自定义节奏"])
        XCTAssertEqual(titles(on: date(2026, 10, 24), in: viewModel), ["自定义节奏"])
        XCTAssertFalse(titles(on: date(2026, 10, 23), in: viewModel).contains("自定义节奏"))
    }

    func testUncommittedInvalidIntervalDraftDoesNotWrite() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.selectDay(date(2026, 10, 20))
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.title = "不会写入"
        viewModel.customIntervalDraft = "abc"

        await viewModel.createReviewSchedule()

        XCTAssertEqual(viewModel.resultType, .error)
        XCTAssertEqual(viewModel.reviewIntervals, [3, 7, 30])
        XCTAssertTrue(calendar.lastCreatedEventIdentifiers.isEmpty)
        XCTAssertEqual(viewModel.customIntervalDraft, "abc")
        XCTAssertEqual(viewModel.baseDate, date(2026, 10, 20))
    }

    func testDeletingADayEventRefreshesTheVisibleMonthWindowAndDayBrowseRows() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let dayAfterTomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: tomorrow))
        let calendar = RangeQueryCalendar(events: [
            event(id: "today-a", title: "今日", start: today, end: tomorrow, isAllDay: true),
            event(id: "tomorrow-b", title: "明日", start: tomorrow, end: dayAfterTomorrow, isAllDay: true),
        ])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.selectDay(today)
        viewModel.selectDayType(.today)
        XCTAssertEqual(ids(on: today, in: viewModel), ["today-a"])
        XCTAssertEqual(viewModel.displayedDayHits.map(\.id), ["today-a"])

        let target = try XCTUnwrap(viewModel.eventsByDay[today]?.first)
        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: target.id, on: today))
        XCTAssertFalse(hit.needsSelectiveDelete)
        XCTAssertTrue(viewModel.deleteSearchHit(hit))

        let monthStart = try XCTUnwrap(
            Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: today))
        )
        XCTAssertEqual(viewModel.visibleMonth, monthStart)
        XCTAssertEqual(ids(on: today, in: viewModel), [])
        XCTAssertEqual(ids(on: tomorrow, in: viewModel), ["tomorrow-b"])
        XCTAssertTrue(viewModel.displayedDayHits.isEmpty)
        XCTAssertNil(calendar.event(withId: "today-a"))
    }

    func testSelectiveSeriesDeleteRefreshesTheVisibleMonthWindow() async throws {
        let calendar = RangeQueryCalendar(events: [])
        let viewModel = ReviewViewModel(calendar: calendar, defaults: freshDefaults())
        viewModel.title = "窗口系列"
        viewModel.baseDate = date(2026, 10, 20)
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .success)

        let firstReviewDay = date(2026, 10, 23)
        let member = try XCTUnwrap(viewModel.eventsByDay[firstReviewDay]?.first)
        let hit = try XCTUnwrap(viewModel.projectedHit(forEventId: member.id, on: firstReviewDay))
        XCTAssertTrue(hit.needsSelectiveDelete)
        XCTAssertEqual(hit.members.count, 3)

        viewModel.beginSeriesDelete(hit)
        XCTAssertEqual(viewModel.seriesPendingDelete?.id, hit.id)

        let removed = try XCTUnwrap(
            hit.members.first { Calendar.current.isDate($0.start, inSameDayAs: date(2026, 10, 27)) }
        )
        let outcome = viewModel.deleteSearchHitMembers(ids: [removed.id])

        XCTAssertEqual(outcome.deletedCount, 1)
        XCTAssertNil(viewModel.seriesPendingDelete)
        XCTAssertFalse(ids(on: firstReviewDay, in: viewModel).contains(removed.id))
        XCTAssertEqual(
            try XCTUnwrap(viewModel.projectedHit(forEventId: member.id, on: firstReviewDay)).members.count,
            2
        )

        let windowGrouped = CalendarEventGrouping.byDay(
            calendar.fetchEvents(from: date(2026, 9, 28), to: date(2026, 11, 9))
        )
        XCTAssertEqual(Set(viewModel.eventsByDay.keys), Set(windowGrouped.keys))
        for (day, events) in windowGrouped {
            XCTAssertEqual(ids(on: day, in: viewModel), events.map(\.id))
            XCTAssertFalse(events.contains(where: { $0.id == removed.id }))
        }
    }

    private func ids(on day: Date, in viewModel: ReviewViewModel) -> [String] {
        viewModel.eventsByDay[day]?.map(\.id) ?? []
    }

    private func titles(on day: Date, in viewModel: ReviewViewModel) -> [String] {
        viewModel.eventsByDay[day]?.map(\.title) ?? []
    }

    private func event(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool
    ) -> CalendarEventInfo {
        CalendarEventInfo(
            id: id,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            notes: nil,
            calendarId: "outlook-default",
            calendarTitle: "日历",
            calendarSourceTitle: "Outlook",
            colorHex: "#0078D4"
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        dateTime(y, m, d, 0, 0)
    }

    private func dateTime(_ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}

@MainActor
final class RangeQueryCalendar: CalendarService {
    struct Range: Equatable {
        let start: Date
        let end: Date
    }

    private let inner: InMemoryCalendarService
    private(set) var rangeFetches: [Range] = []
    private(set) var dayFetches = 0

    init(events: [CalendarEventInfo]) {
        inner = InMemoryCalendarService(grantAccessByDefault: true, events: events)
    }

    var authorizationStatus: CalendarAccessStatus { inner.authorizationStatus }
    var availableCalendars: [CalendarInfo] { inner.availableCalendars }
    var hasCloudCalendar: Bool { inner.hasCloudCalendar }
    var lastCreatedEventIdentifiers: [String] { inner.lastCreatedEventIdentifiers }

    func requestAccess() async -> Bool { await inner.requestAccess() }
    func refreshAvailableCalendars() { inner.refreshAvailableCalendars() }
    func checkAuthorizationStatus() -> CalendarAccessStatus { inner.checkAuthorizationStatus() }
    func calendar(withIdentifier identifier: String) -> CalendarInfo? { inner.calendar(withIdentifier: identifier) }
    func defaultCalendar() -> CalendarInfo? { inner.defaultCalendar() }

    func createReviewEvents(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String?,
        detail: String?
    ) async throws -> CreateEventsResult {
        try await inner.createReviewEvents(
            title: title,
            baseDate: baseDate,
            intervals: intervals,
            calendarId: calendarId,
            detail: detail
        )
    }

    func createSingleEvent(
        title: String,
        date: Date,
        calendarId: String?,
        detail: String?
    ) async throws -> CreateEventsResult {
        try await inner.createSingleEvent(title: title, date: date, calendarId: calendarId, detail: detail)
    }

    func undoLastCreation() async -> UndoResult { await inner.undoLastCreation() }

    func fetchEvents(on date: Date) -> [CalendarEventInfo] {
        dayFetches += 1
        return inner.fetchEvents(on: date)
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEventInfo] {
        rangeFetches.append(Range(start: start, end: end))
        return inner.fetchEvents(from: start, to: end)
    }

    func event(withId id: String) -> CalendarEventInfo? { inner.event(withId: id) }
    func deleteEvent(id: String) -> Bool { inner.deleteEvent(id: id) }
    func event(matching address: EventAddress) -> CalendarEventInfo? { inner.event(matching: address) }
    func removeEvent(at address: EventAddress, preferredId: String?) -> EventRemovalOutcome {
        inner.removeEvent(at: address, preferredId: preferredId)
    }
    func searchEvents(query: String, daysAhead: Int) -> [CalendarEventInfo] {
        inner.searchEvents(query: query, daysAhead: daysAhead)
    }
    func eventNotes(id: String) -> String? { inner.eventNotes(id: id) }
    func updateEventNotes(id: String, notes: String) -> Bool { inner.updateEventNotes(id: id, notes: notes) }
    func updateEventTitle(id: String, title: String) -> Bool { inner.updateEventTitle(id: id, title: title) }
}
