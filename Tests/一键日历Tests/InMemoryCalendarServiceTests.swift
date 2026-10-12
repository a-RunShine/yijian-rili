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

    func testUpdateEventTitleRewritesExistingAndReturnsFalseWhenMissing() async throws {
        let calendar = InMemoryCalendarService()
        let result = try await calendar.createReviewEvents(
            title: "旧标题",
            baseDate: date(2026, 1, 31),
            intervals: [3],
            calendarId: nil
        )
        XCTAssertEqual(result.created.count, 1)
        let id = try XCTUnwrap(calendar.lastCreatedEventIdentifiers.first)

        XCTAssertTrue(calendar.updateEventTitle(id: id, title: "新标题"))
        XCTAssertEqual(calendar.event(withId: id)?.title, "新标题")
        XCTAssertFalse(calendar.updateEventTitle(id: "missing-id", title: "不应写入"))
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

    func testUndoClearsTodayCreatedAndWeeklyViaFacade() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "tip-smoke-undo-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = date(2026, 2, 1)
        viewModel.scheduleMode = .single
        viewModel.updateReviewDates()

        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .success)
        XCTAssertTrue(viewModel.todayCreatedEntries.contains(where: { $0.title == marker }))
        XCTAssertTrue(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.title == marker })
        )

        await viewModel.undoReviewSchedule()
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertFalse(viewModel.todayCreatedEntries.contains(where: { $0.title == marker }))
        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.title == marker })
        )
    }

    func testDeleteSearchResultClearsTodayCreatedAndWeeklyViaFacade() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "tip-smoke-del-\(UUID().uuidString.prefix(8))"
        let eventDay = Date()
        viewModel.title = marker
        viewModel.baseDate = eventDay
        viewModel.scheduleMode = .single
        viewModel.updateReviewDates()

        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .success)
        let batchID = viewModel.todayCreatedEntries.first(where: { $0.title == marker })?.id
        XCTAssertNotNil(batchID)
        XCTAssertTrue(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.title == marker })
        )

        viewModel.searchText = marker
        viewModel.performSearch()
        XCTAssertEqual(viewModel.searchHits.count, 1, "search must find the created event")
        let hit = viewModel.searchHits[0]
        XCTAssertFalse(hit.needsSelectiveDelete)
        XCTAssertTrue(viewModel.deleteSearchHit(hit))

        XCTAssertTrue(calendar.fetchEvents(on: eventDay).isEmpty)
        XCTAssertFalse(viewModel.todayCreatedEntries.contains(where: { $0.title == marker }))
        XCTAssertFalse(
            viewModel.historyEntries.contains(where: { $0.id == batchID }),
            "delete-from-browse must discard 今日所建 batch"
        )
        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.title == marker }),
            "delete-from-browse must discard 周末总结 source"
        )
    }

    func testSearchCollapsesReviewSeriesToOneHit() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "series-collapse-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()

        await viewModel.createReviewSchedule()
        XCTAssertEqual(viewModel.resultType, .success)

        viewModel.searchText = marker
        viewModel.performSearch()

        XCTAssertEqual(viewModel.searchHits.count, 1)
        XCTAssertTrue(viewModel.searchHits[0].isSeries)
        XCTAssertEqual(viewModel.searchHits[0].members.count, 3)
        XCTAssertTrue(viewModel.searchHits[0].needsSelectiveDelete)
    }

    func testSelectiveSeriesDeletePartialKeepsTodayCreatedAndWeekly() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "series-partial-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()

        await viewModel.createReviewSchedule()
        let batch = try XCTUnwrap(viewModel.todayCreatedEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(batch.createdEventIdentifiers.count, 3)

        viewModel.searchText = marker
        viewModel.performSearch()
        let hit = try XCTUnwrap(viewModel.searchHits.first)
        let removeID = hit.members[0].id
        let outcome = viewModel.deleteSearchHitMembers(ids: [removeID])

        XCTAssertEqual(outcome.deletedCount, 1)
        XCTAssertNil(calendar.event(withId: removeID))
        let after = try XCTUnwrap(viewModel.todayCreatedEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(after.id, batch.id)
        XCTAssertEqual(after.createdEventIdentifiers.count, 2)
        XCTAssertFalse(after.createdEventIdentifiers.contains(removeID))
        XCTAssertTrue(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.id == batch.id })
        )

        viewModel.performSearch()
        XCTAssertEqual(viewModel.searchHits.count, 1)
        XCTAssertEqual(viewModel.searchHits[0].members.count, 2)
    }

    func testSelectiveSeriesDeleteAllDiscardsTodayCreatedAndWeekly() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "series-all-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()

        await viewModel.createReviewSchedule()
        let batchID = try XCTUnwrap(viewModel.todayCreatedEntries.first(where: { $0.title == marker })?.id)

        viewModel.searchText = marker
        viewModel.performSearch()
        let ids = try XCTUnwrap(viewModel.searchHits.first?.members.map(\.id))
        let outcome = viewModel.deleteSearchHitMembers(ids: ids)

        XCTAssertEqual(outcome.deletedCount, 3)
        XCTAssertFalse(viewModel.todayCreatedEntries.contains(where: { $0.title == marker }))
        XCTAssertFalse(viewModel.historyEntries.contains(where: { $0.id == batchID }))
        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.id == batchID })
        )
        viewModel.performSearch()
        XCTAssertTrue(viewModel.searchHits.isEmpty)
    }

    func testSearchRebuildReconcilesGhostSeriesMembers() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "search-reconcile-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        XCTAssertEqual(ids.count, 3)
        for id in ids {
            XCTAssertTrue(calendar.deleteEvent(id: id))
        }

        viewModel.searchText = marker
        viewModel.performSearch()

        XCTAssertTrue(viewModel.searchHits.isEmpty)
        XCTAssertFalse(viewModel.historyEntries.contains(where: { $0.id == batch.id }))
        XCTAssertFalse(viewModel.todayCreatedEntries.contains(where: { $0.id == batch.id }))
        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.id == batch.id })
        )
    }

    func testTodayCreatedListingReconcilesPartialMissingMembers() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "today-reconcile-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        XCTAssertTrue(calendar.deleteEvent(id: ids[0]))

        let listed = viewModel.todayCreatedEntries
        let after = try XCTUnwrap(listed.first(where: { $0.title == marker }))
        XCTAssertEqual(after.id, batch.id)
        XCTAssertEqual(after.createdEventIdentifiers.count, 2)
        XCTAssertFalse(after.createdEventIdentifiers.contains(ids[0]))
        XCTAssertTrue(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.id == batch.id })
        )
    }

    func testDayLoadReconcilesMissingMembers() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "day-reconcile-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        for id in ids {
            XCTAssertTrue(calendar.deleteEvent(id: id))
        }

        viewModel.loadDisplayedDayEvents()

        XCTAssertFalse(viewModel.historyEntries.contains(where: { $0.id == batch.id }))
        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: { $0.id == batch.id })
        )
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

    func testUpdateSeriesTitleViaFacadeUpdatesHistoryTodayCreatedAndWeekly() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "旧门面标题"
        viewModel.detail = "保留详情"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        guard let entry = viewModel.historyEntries.first else {
            return XCTFail("expected history entry")
        }
        let batchID = entry.id
        XCTAssertTrue(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: {
                $0.id == batchID && $0.title == "旧门面标题"
            })
        )

        let outcome = viewModel.updateSeriesTitle(for: entry, title: "  新门面标题  ")
        XCTAssertEqual(outcome, .updated(updated: 3, missing: 0))
        XCTAssertEqual(viewModel.historyEntries.first?.title, "新门面标题")
        XCTAssertEqual(viewModel.todayCreatedEntries.first?.title, "新门面标题")
        XCTAssertEqual(viewModel.historyEntries.first?.sharedDetail, "保留详情")
        XCTAssertTrue(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: {
                $0.id == batchID && $0.title == "新门面标题"
            })
        )
        XCTAssertFalse(
            viewModel.weeklyReviewViewModel.weeklyEntries.contains(where: {
                $0.id == batchID && $0.title == "旧门面标题"
            })
        )
        XCTAssertEqual(viewModel.resultType, .success)
        for id in entry.createdEventIdentifiers {
            XCTAssertEqual(calendar.event(withId: id)?.title, "新门面标题")
        }
    }

    func testCommitSharedDetailEditAlsoSavesSeriesTitle() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "提交前"
        viewModel.detail = "旧详情"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        guard let entry = viewModel.historyEntries.first else {
            return XCTFail("expected history entry")
        }
        viewModel.beginSharedDetailEdit(for: entry)
        XCTAssertEqual(viewModel.seriesTitleDraft, "提交前")
        XCTAssertEqual(viewModel.sharedDetailDraft, "旧详情")

        viewModel.seriesTitleDraft = "提交后标题"
        viewModel.sharedDetailDraft = "提交后详情"
        let outcome = viewModel.commitSharedDetailEdit()

        XCTAssertEqual(outcome, .updated(updated: 3, missing: 0))
        XCTAssertEqual(viewModel.historyEntries.first?.title, "提交后标题")
        XCTAssertEqual(viewModel.historyEntries.first?.sharedDetail, "提交后详情")
        XCTAssertTrue(viewModel.sharedDetailEditOutcomeVisible)
        XCTAssertEqual(viewModel.resultType, .success)
        let titleMessage = String(format: NSLocalizedString("series_title_success", comment: ""), "3")
        XCTAssertEqual(viewModel.resultMessage, titleMessage)
    }

    func testCommitSharedDetailEditWithEmptyTitleStillSavesDetail() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "仅改详情"
        viewModel.detail = "旧详情"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        guard let entry = viewModel.historyEntries.first else {
            return XCTFail("expected history entry")
        }
        viewModel.beginSharedDetailEdit(for: entry)
        viewModel.seriesTitleDraft = "   "
        viewModel.sharedDetailDraft = "只更新详情"
        let outcome = viewModel.commitSharedDetailEdit()

        XCTAssertEqual(outcome, .updated(updated: 3, missing: 0))
        XCTAssertEqual(viewModel.historyEntries.first?.title, "仅改详情")
        XCTAssertEqual(viewModel.historyEntries.first?.sharedDetail, "只更新详情")
        XCTAssertEqual(viewModel.resultType, .success)
        let detailMessage = String(format: NSLocalizedString("shared_detail_success", comment: ""), "3")
        XCTAssertEqual(viewModel.resultMessage, detailMessage)
    }


    func testBeginSharedDetailEditFromBrowseResolvesHistoryAndUsesSharedDetail() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "浏览点开"
        viewModel.detail = "初始详情"
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        guard let entry = viewModel.historyEntries.first,
              let eventId = entry.createdEventIdentifiers.first else {
            return XCTFail("expected created event id")
        }

        let event = calendar.event(withId: eventId)!
        viewModel.beginSharedDetailEditFromBrowse(event)

        XCTAssertEqual(viewModel.editingSharedDetailEntryID, entry.id)
        XCTAssertNil(viewModel.browseSharedDetailUnavailableEvent)
        XCTAssertEqual(viewModel.sharedDetailDraft, "初始详情")
        XCTAssertTrue(viewModel.canEditSharedDetailForSelection)
    }

    func testBeginSharedDetailEditFromBrowseFillsDraftFromNotesWhenSharedDetailNil() async {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        viewModel.title = "从备注填"
        viewModel.detail = ""
        viewModel.baseDate = date(2026, 1, 31)
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        guard let entry = viewModel.historyEntries.first,
              let eventId = entry.createdEventIdentifiers.first else {
            return XCTFail("expected created event id")
        }
        XCTAssertNil(entry.sharedDetail)

        let composed = ReviewNotes.compose(key: "第1次复习", detail: "从日历备注")
        calendar.updateEventNotes(id: eventId, notes: composed)
        let event = calendar.event(withId: eventId)!

        viewModel.beginSharedDetailEditFromBrowse(event)

        XCTAssertEqual(viewModel.editingSharedDetailEntryID, entry.id)
        XCTAssertEqual(viewModel.sharedDetailDraft, "从日历备注")
    }

    func testBeginSharedDetailEditFromBrowseUnavailableWhenUnmatched() {
        let viewModel = ReviewViewModel(calendar: InMemoryCalendarService(grantAccessByDefault: true))
        let event = CalendarEventInfo(
            id: "holiday-1",
            title: "国庆节",
            start: date(2026, 10, 1),
            end: date(2026, 10, 1),
            isAllDay: true,
            notes: nil,
            calendarId: nil,
            calendarTitle: "中国大陆节假日",
            calendarSourceTitle: nil,
            colorHex: nil
        )
        viewModel.beginSharedDetailEditFromBrowse(event)
        XCTAssertNil(viewModel.editingSharedDetailEntryID)
        XCTAssertEqual(viewModel.browseSharedDetailUnavailableEvent?.id, "holiday-1")
        XCTAssertFalse(viewModel.canEditSharedDetailForSelection)
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

    func testDayLoadProjectsReviewMemberAsSeriesAwareRow() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "day-series-\(UUID().uuidString.prefix(8))"
        let base = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        viewModel.title = marker
        viewModel.detail = "系列详情"
        viewModel.baseDate = base
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        XCTAssertEqual(batch.createdEventIdentifiers.count, 3)

        viewModel.selectDayType(.today)
        let rows = viewModel.displayedDayHits
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertTrue(row.isSeries)
        XCTAssertEqual(row.kind, .series(historyEntryID: batch.id))
        XCTAssertEqual(row.title, marker)
        XCTAssertEqual(row.members.count, 3)
        XCTAssertTrue(row.needsSelectiveDelete)
        XCTAssertEqual(row.focusedEvent.id, row.id)
        XCTAssertTrue(batch.createdEventIdentifiers.contains(row.id))
    }

    func testDayLoadProjectsSingleAndUnmatchedAsSingleRows() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "day-single-\(UUID().uuidString.prefix(8))"
        viewModel.title = marker
        viewModel.baseDate = Date()
        viewModel.scheduleMode = .single
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        viewModel.selectDayType(.today)
        let rows = viewModel.displayedDayHits
        XCTAssertEqual(rows.count, 1)
        XCTAssertFalse(rows[0].isSeries)
        XCTAssertEqual(rows[0].kind, .single)
        XCTAssertEqual(rows[0].title, marker)
        XCTAssertFalse(rows[0].needsSelectiveDelete)
    }

    func testDaySeriesRowEditAndSelectiveDeleteReuseSearchPaths() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "day-ops-\(UUID().uuidString.prefix(8))"
        let base = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        viewModel.title = marker
        viewModel.detail = "可编辑"
        viewModel.baseDate = base
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        viewModel.selectDayType(.today)
        let row = try XCTUnwrap(viewModel.displayedDayHits.first)
        XCTAssertTrue(row.isSeries)

        viewModel.beginSharedDetailEditFromBrowse(row.focusedEvent)
        XCTAssertEqual(viewModel.editingSharedDetailEntryID, batch.id)
        XCTAssertEqual(viewModel.sharedDetailDraft, "可编辑")
        viewModel.cancelSharedDetailEdit()

        viewModel.beginSeriesDelete(row)
        XCTAssertEqual(viewModel.seriesPendingDelete?.id, row.id)
        XCTAssertEqual(viewModel.seriesPendingDelete?.members.count, 3)

        let removeID = row.members.first(where: { $0.id != row.id })?.id
            ?? row.members[0].id
        let outcome = viewModel.deleteSearchHitMembers(ids: [removeID])
        XCTAssertEqual(outcome.deletedCount, 1)
        XCTAssertNil(viewModel.seriesPendingDelete)

        viewModel.selectDayType(.today)
        let after = try XCTUnwrap(viewModel.displayedDayHits.first)
        XCTAssertTrue(after.isSeries)
        XCTAssertEqual(after.members.count, 2)
        XCTAssertFalse(after.members.contains(where: { $0.id == removeID }))
    }

    func testDayLoadKeepsOneRowPerDayEventAndStillReconciles() async throws {
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let viewModel = ReviewViewModel(calendar: calendar)
        let marker = "day-reconcile-rows-\(UUID().uuidString.prefix(8))"
        let base = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        viewModel.title = marker
        viewModel.baseDate = base
        viewModel.scheduleMode = .review
        viewModel.reviewIntervals = [3, 7, 30]
        viewModel.updateReviewDates()
        await viewModel.createReviewSchedule()

        let batch = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.title == marker }))
        let ids = batch.createdEventIdentifiers
        XCTAssertTrue(calendar.deleteEvent(id: ids[1]))
        XCTAssertTrue(calendar.deleteEvent(id: ids[2]))

        viewModel.loadDisplayedDayEvents()

        let remaining = try XCTUnwrap(viewModel.historyEntries.first(where: { $0.id == batch.id }))
        XCTAssertEqual(remaining.createdEventIdentifiers, [ids[0]])
        XCTAssertEqual(viewModel.displayedDayHits.count, 1)
        XCTAssertTrue(viewModel.displayedDayHits[0].isSeries)
        XCTAssertEqual(viewModel.displayedDayHits[0].members.count, 1)
        XCTAssertFalse(viewModel.displayedDayHits[0].needsSelectiveDelete)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        return Calendar.current.date(from: components)!
    }
}
