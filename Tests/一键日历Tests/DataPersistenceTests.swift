import XCTest
@testable import 一键日历

@MainActor
final class HistoryStoreCorruptionTests: XCTestCase {
    private func suite(_ label: String) -> (UserDefaults, String) {
        let name = "audit-\(label)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func entry(_ title: String, id: UUID = UUID()) -> HistoryEntry {
        HistoryEntry(
            id: id,
            title: title,
            baseDate: Date(timeIntervalSince1970: 1_700_000_000),
            reviewDates: [Date(timeIntervalSince1970: 1_700_259_200)],
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            type: .review,
            createdEventIdentifiers: ["id-\(title)"]
        )
    }

    func testAddSurvivesTruncatedHistoryPayload() {
        let (defaults, name) = suite("truncated")
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(defaults: defaults)
        store.add(entry("甲"))
        store.add(entry("乙"))

        let intact = defaults.string(forKey: HistoryStore.storageKey)!
        XCTAssertEqual(store.load().count, 2)
        defaults.set(String(intact.dropLast(7)), forKey: HistoryStore.storageKey)

        store.add(entry("丙"))

        XCTAssertEqual(
            store.load().count,
            3,
            "截断的持久化载荷不应让 add() 清空既有历史"
        )
    }

    func testAddSurvivesPayloadWithOneEntryMissingField() throws {
        let (defaults, name) = suite("missing-field")
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(defaults: defaults)
        store.add(entry("甲"))
        store.add(entry("乙"))

        let intact = defaults.string(forKey: HistoryStore.storageKey)!
        let broken = intact.replacingOccurrences(of: "\"title\":\"乙\"", with: "\"label\":\"乙\"")
        XCTAssertNotEqual(broken, intact)
        defaults.set(broken, forKey: HistoryStore.storageKey)

        store.add(entry("丙"))

        XCTAssertEqual(
            store.load().count,
            3,
            "单条记录缺字段不应连带丢掉其余记录"
        )
    }

    func testAddSurvivesNonJSONPayload() {
        let (defaults, name) = suite("non-json")
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(defaults: defaults)
        store.add(entry("甲"))
        store.add(entry("乙"))

        defaults.set("<html>502 Bad Gateway</html>", forKey: HistoryStore.storageKey)

        _ = store.load()
        XCTAssertTrue(store.lastHealth.isDamaged, "外部写坏主键后应被标记为已损坏")

        store.add(entry("丙"))

        XCTAssertEqual(store.load().count, 3, "非法载荷不应被当成空历史覆盖写回")
    }

    func testRemoveSurvivesCorruptPayload() {
        let (defaults, name) = suite("remove")
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(defaults: defaults)
        store.add(entry("甲"))
        store.add(entry("乙"))
        let target = store.load()[1]

        defaults.set("not json at all", forKey: HistoryStore.storageKey)
        store.remove(id: target.id)

        XCTAssertEqual(
            store.load().count,
            1,
            "删除单条应只少那一条，不应在载荷损坏时清空全部"
        )
    }
}

@MainActor
final class HistoryStoreCapTests: XCTestCase {
    private func suite(_ label: String) -> (UserDefaults, String) {
        let name = "audit-cap-\(label)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func entry(_ index: Int) -> HistoryEntry {
        HistoryEntry(
            title: "批次\(index)",
            baseDate: Date(timeIntervalSince1970: 1_700_000_000),
            reviewDates: [],
            creationDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
            type: .review,
            createdEventIdentifiers: []
        )
    }

    func testAddBeyondCapDropsOldestEntries() {
        let (defaults, name) = suite("drop-oldest")
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HistoryStore(defaults: defaults)
        for index in 0..<25 {
            store.add(entry(index))
        }

        let titles = store.load().map(\.title)
        XCTAssertEqual(titles.count, 20)
        XCTAssertEqual(titles.first, "批次24", "最新一条保留在首位")
        XCTAssertEqual(titles.last, "批次5", "被丢弃的是最旧的 5 条")
        XCTAssertFalse(titles.contains("批次0"))
    }

    func testLoadTruncatesOversizedPayloadWithoutWritingBack() {
        let (defaults, name) = suite("no-writeback")
        defer { defaults.removePersistentDomain(forName: name) }
        let payload = (0..<25).map(entry)
        let data = try! JSONEncoder().encode(payload)
        defaults.set(String(data: data, encoding: .utf8)!, forKey: HistoryStore.storageKey)

        let store = HistoryStore(defaults: defaults)
        XCTAssertEqual(store.load().count, 20)
        let raw = try! JSONDecoder().decode(
            [HistoryEntry].self,
            from: defaults.string(forKey: HistoryStore.storageKey)!.data(using: .utf8)!
        )
        XCTAssertEqual(raw.count, 25, "load() 只截断视图，未回写磁盘")

        store.add(entry(99))
        let after = try! JSONDecoder().decode(
            [HistoryEntry].self,
            from: defaults.string(forKey: HistoryStore.storageKey)!.data(using: .utf8)!
        )
        XCTAssertEqual(after.count, 20, "下一次 add() 把磁盘上的 25 条永久压成 20 条")
        XCTAssertEqual(after.first?.title, "批次99")
    }
}

@MainActor
final class OccurrenceStatusReassignmentTests: XCTestCase {
    func testDoneMarkSurvivesIdentifierReassignment() async throws {
        let name = "audit-status-reassign-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            occurrenceStatuses: statuses
        )

        session.title = "重分配完成态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        XCTAssertEqual(ids.count, 3)
        session.setOccurrenceStatus(eventId: ids[0], status: .done)
        session.setOccurrenceStatus(eventId: ids[1], status: .skipped)
        XCTAssertEqual(session.occurrenceStatus(for: ids[0]), .done)

        let remapped = calendar.reassignAllEventIdentifiersForTesting()
        let fresh = try XCTUnwrap(remapped[ids[0]])
        let freshSkipped = try XCTUnwrap(remapped[ids[1]])

        session.reconcileRecordedWithCalendar()

        XCTAssertTrue(session.canMarkOccurrence(eventId: fresh))
        XCTAssertEqual(
            session.occurrenceStatus(for: fresh),
            .done,
            "eventId 重分配后完成标记不应退回 unmarked"
        )
        XCTAssertEqual(
            session.occurrenceStatus(for: freshSkipped),
            .skipped,
            "eventId 重分配后跳过标记不应退回 unmarked"
        )
    }

    func testStaleIdsAccumulateInStatusStoreAfterReassignment() async throws {
        let name = "audit-status-stale-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            occurrenceStatuses: statuses
        )

        session.title = "孤儿状态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()

        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)
        session.setOccurrenceStatus(eventId: ids[0], status: .done)

        _ = calendar.reassignAllEventIdentifiersForTesting()

        XCTAssertEqual(statuses.markedEntries().count, 1)
        XCTAssertTrue(
            statuses.markedEntries().keys.contains(where: { $0.hasPrefix("series:") }),
            "状态应挂在系列身份上，events 重分配 id 后键不变"
        )
        let materials = session.occurrenceMaterials(
            weekStart: WeekCalculator.weekStart(for: Date()),
            weekEnd: WeekCalculator.weekEnd(for: WeekCalculator.weekStart(for: Date()))
        )
        XCTAssertEqual(materials.count, 1, "周回顾素材在重分配后应仍然可见")
    }
}

@MainActor
final class UndoAndPruneIdMismatchTests: XCTestCase {
    private func suite(_ label: String) -> (UserDefaults, String) {
        let name = "audit-undo-\(label)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func makeSession(
        calendar: InMemoryCalendarService,
        defaults: UserDefaults
    ) -> (ReviewSession, HistoryStore, OccurrenceStatusStore) {
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            occurrenceStatuses: statuses
        )
        return (session, history, statuses)
    }

    func testUndoThatDeletesNothingStillDiscardsHistory() async throws {
        let (defaults, name) = suite("no-delete")
        defer { defaults.removePersistentDomain(forName: name) }
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, _) = makeSession(calendar: calendar, defaults: defaults)

        session.title = "撤销失败"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()
        let eventsBefore = calendar.fetchEvents(
            from: Date().addingTimeInterval(-86_400),
            to: Date().addingTimeInterval(86_400 * 40)
        )
        XCTAssertEqual(eventsBefore.count, 3)

        _ = calendar.reassignAllEventIdentifiersForTesting()
        await session.undo()

        XCTAssertEqual(session.resultType, .warning)
        XCTAssertEqual(
            calendar.fetchEvents(
                from: Date().addingTimeInterval(-86_400),
                to: Date().addingTimeInterval(86_400 * 40)
            ).count,
            3,
            "重分配后撤销事件数为 0"
        )
        XCTAssertFalse(
            history.load().isEmpty,
            "一个事件都没删掉时不应丢弃历史，否则历史与日历从此不一致"
        )
    }

    func testDeleteOfReassignedOccurrenceLeavesHistoryUnpruned() async throws {
        let (defaults, name) = suite("prune-miss")
        defer { defaults.removePersistentDomain(forName: name) }
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let (session, history, _) = makeSession(calendar: calendar, defaults: defaults)

        session.title = "删除漏配"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7, 30]
        session.updateReviewDates()
        await session.create()
        let ids = try XCTUnwrap(history.load().first?.createdEventIdentifiers)

        let remapped = calendar.reassignAllEventIdentifiersForTesting()
        let fresh = try XCTUnwrap(remapped[ids[0]])
        XCTAssertTrue(calendar.deleteEvent(id: fresh))

        let outcome = session.removeEventsFromRecorded(ids: [fresh], reason: .userDeletedOccurrence)

        XCTAssertEqual(outcome, .noMatch)
        XCTAssertEqual(
            history.load().first?.createdEventIdentifiers,
            ids,
            "已删掉的成员仍在历史里，历史保留了永不存在的 id"
        )
    }
}

@MainActor
final class PersistenceSwallowTests: XCTestCase {
    private func suite(_ label: String) -> (UserDefaults, String) {
        let name = "audit-swallow-\(label)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    func testWeeklyEntriesSurviveCorruptPayloadOnAppend() {
        let (defaults, name) = suite("weekly")
        defer { defaults.removePersistentDomain(forName: name) }
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        weekly.appendWeeklyEntry(from: HistoryEntry(
            title: "周甲",
            baseDate: Date(),
            reviewDates: [],
            creationDate: Date(),
            type: .review
        ))
        weekly.appendWeeklyEntry(from: HistoryEntry(
            title: "周乙",
            baseDate: Date(),
            reviewDates: [],
            creationDate: Date(),
            type: .review
        ))
        XCTAssertEqual(weekly.weeklyEntries.count, 2)

        defaults.set("[{\"id\":\"oops\"}]", forKey: WeeklyReviewViewModel.weeklyEntriesKey)
        weekly.appendWeeklyEntry(from: HistoryEntry(
            title: "周丙",
            baseDate: Date(),
            reviewDates: [],
            creationDate: Date(),
            type: .review
        ))

        XCTAssertEqual(weekly.weeklyEntries.count, 3, "周回顾条目不应在解码失败后被覆盖清零")
    }

    func testReviewedMarksSurviveCorruptPayloadOnToggle() {
        let (defaults, name) = suite("reviewed")
        defer { defaults.removePersistentDomain(forName: name) }
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let first = UUID()
        let second = UUID()
        weekly.toggleReviewed(first)
        weekly.toggleReviewed(second)
        XCTAssertEqual(weekly.reviewedIds.count, 2)

        defaults.set("[\"broken\"]", forKey: WeeklyReviewViewModel.weeklyReviewStateKey)
        weekly.toggleReviewed(UUID())

        XCTAssertEqual(weekly.reviewedIds.count, 3, "已复习标记不应在解码失败后被覆盖清零")
    }

    func testOccurrenceStatusSurvivesCorruptPayloadOnSet() {
        let (defaults, name) = suite("status")
        defer { defaults.removePersistentDomain(forName: name) }
        let store = OccurrenceStatusStore(defaults: defaults)
        store.setStatus(.done, for: "a")
        store.setStatus(.skipped, for: "b")
        XCTAssertEqual(store.markedEntries().count, 2)

        defaults.set("{\"a\":\"done\"", forKey: OccurrenceStatusStore.storageKey)
        store.setStatus(.done, for: "c")

        XCTAssertEqual(store.markedEntries().count, 3, "完成态不应在解码失败后被覆盖清零")
    }

    func testHistoryMigrationMarkerIsNotBurnedWhenLegacyPayloadIsCorrupt() {
        let (defaults, name) = suite("migration")
        defer { defaults.removePersistentDomain(forName: name) }
        let legacy = try! JSONEncoder().encode([
            HistoryEntry(title: "旧甲", baseDate: Date(), reviewDates: [], creationDate: Date(), type: .review),
            HistoryEntry(title: "旧乙", baseDate: Date(), reviewDates: [], creationDate: Date(), type: .review)
        ])
        defaults.set(String(data: legacy, encoding: .utf8)!, forKey: HistoryStore.storageKey)
        defaults.set("[]", forKey: WeeklyReviewViewModel.weeklyEntriesKey)

        let broken = String(data: legacy, encoding: .utf8)!.replacingOccurrences(
            of: "\"title\":\"旧乙\"",
            with: "\"label\":\"旧乙\""
        )
        defaults.set(broken, forKey: HistoryStore.storageKey)

        let weekly = WeeklyReviewViewModel(defaults: defaults)
        XCTAssertFalse(
            weekly.weeklyEntries.isEmpty,
            "旧数据部分损坏时应尽量迁移能读的条目"
        )
        XCTAssertTrue(
            defaults.bool(forKey: WeeklyReviewViewModel.historyMigrationKey),
            "迁移成功后应标记完成，避免每次启动重复迁移"
        )
    }
}

@MainActor
final class GatedCalendarService: CalendarService {
    private let inner: InMemoryCalendarService
    private var pending: [CheckedContinuation<Void, Never>] = []
    private var gateOpen = false
    var onEnterCreate: (() -> Void)?

    init(inner: InMemoryCalendarService) {
        self.inner = inner
    }

    var authorizationStatus: CalendarAccessStatus { inner.authorizationStatus }
    var availableCalendars: [CalendarInfo] { inner.availableCalendars }
    var hasCloudCalendar: Bool { inner.hasCloudCalendar }

    func requestAccess() async -> Bool { await inner.requestAccess() }
    func refreshAvailableCalendars() { inner.refreshAvailableCalendars() }
    func checkAuthorizationStatus() -> CalendarAccessStatus { inner.checkAuthorizationStatus() }
    func calendar(withIdentifier identifier: String) -> CalendarInfo? { inner.calendar(withIdentifier: identifier) }
    func defaultCalendar() -> CalendarInfo? { inner.defaultCalendar() }

    func openGate() {
        gateOpen = true
        let waiting = pending
        pending = []
        for continuation in waiting { continuation.resume() }
    }

    func createReviewEvents(
        title: String,
        baseDate: Date,
        intervals: [Int],
        calendarId: String?,
        detail: String?
    ) async throws -> CreateEventsResult {
        onEnterCreate?()
        if !gateOpen {
            await withCheckedContinuation { pending.append($0) }
        }
        return try await inner.createReviewEvents(
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

    func undoLastCreation(eventIds: [String]) async -> UndoResult {
        await inner.undoLastCreation(eventIds: eventIds)
    }
    func fetchEvents(on date: Date) -> [CalendarEventInfo] { inner.fetchEvents(on: date) }
    func fetchEvents(from start: Date, to end: Date) -> [CalendarEventInfo] { inner.fetchEvents(from: start, to: end) }
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

@MainActor
final class CreateInFlightMutationTests: XCTestCase {
    private func day(_ offset: Int) -> Date {
        Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400 * Double(offset)))
    }

    func testBaseDateChangedDuringCreateWritesInconsistentHistoryEntry() async {
        let name = "audit-inflight-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let inner = InMemoryCalendarService(grantAccessByDefault: true)
        let calendar = GatedCalendarService(inner: inner)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: defaults)
        let original = day(10)
        let hijacked = day(40)

        viewModel.selectDay(original)
        viewModel.title = "并发改日期"
        viewModel.reviewIntervals = [3]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()

        let entered = expectation(description: "create entered")
        calendar.onEnterCreate = { entered.fulfill() }
        let task = Task { await viewModel.createReviewSchedule() }
        await fulfillment(of: [entered], timeout: 5)

        viewModel.selectDay(hijacked)
        calendar.openGate()
        await task.value

        let entries = HistoryStore(defaults: defaults).load()
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        let expectedReviewDay = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 3, to: original)!
        )
        XCTAssertEqual(
            entry.reviewDates.map { Calendar.current.startOfDay(for: $0) },
            [expectedReviewDay],
            "日历里写的是原基准日 +3 天"
        )
        XCTAssertEqual(
            Calendar.current.startOfDay(for: entry.baseDate),
            original,
            "历史记录的基准日期被 create 期间的用户操作改写，与真实事件日期不一致"
        )
    }
}

@MainActor
final class SecondaryPersistenceLossTests: XCTestCase {
    private func suite(_ label: String) -> (UserDefaults, String) {
        let name = "audit-secondary-\(label)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    func testCustomPresetsSurviveCorruptPayloadOnSave() {
        let (defaults, name) = suite("presets")
        defer { defaults.removePersistentDomain(forName: name) }
        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            reviewIntervals: [3, 7, 30],
            customPresets: [],
            defaults: defaults
        )
        session.reviewIntervals = [5]
        session.saveCustomPreset(name: "甲")
        session.reviewIntervals = [9]
        session.saveCustomPreset(name: "乙")
        XCTAssertEqual(session.customPresets.count, 2)

        defaults.set("[{\"name\":\"甲\"", forKey: "customPresetsData")
        let reloaded = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            defaults: defaults
        )
        XCTAssertEqual(reloaded.customPresets.count, 2, "损坏后应从备份恢复，而不是当作空")
        reloaded.reviewIntervals = [11]
        reloaded.saveCustomPreset(name: "丙")

        let after = ReviewSession(calendar: calendar, outcomes: outcomes, defaults: defaults)
        XCTAssertEqual(after.customPresets.count, 3, "自定义间隔预设不应在解码失败后被覆盖为一条")
    }

    func testWeeklyNotesSurviveCorruptPayloadOnEdit() {
        let (defaults, name) = suite("notes")
        defer { defaults.removePersistentDomain(forName: name) }
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        weekly.goToPreviousWeek()
        weekly.updateNote("上周想法")
        weekly.jumpToCurrentWeek()
        weekly.updateNote("本周想法")
        weekly.commitNoteDraft()
        XCTAssertFalse(weekly.currentWeekNote.isEmpty)

        defaults.set("{\"byWeek\":{\"x\":", forKey: WeeklyReviewViewModel.weeklyNotesKey)
        weekly.updateNote("新写的")

        _ = WeeklyReviewViewModel(defaults: defaults)
        let keysWithNotes = (try? JSONDecoder().decode(
            WeeklyNotes.self,
            from: defaults.string(forKey: WeeklyReviewViewModel.weeklyNotesKey)!.data(using: .utf8)!
        ))?.byWeek.filter { !$0.value.isEmpty }.count ?? -1
        XCTAssertEqual(keysWithNotes, 2, "其它周的周记不应在解码失败后被整份覆盖")
    }
}

@MainActor
final class StaleSnapshotOverwriteTests: XCTestCase {
    func testCalendarChoiceMadeDuringCreateIsRevertedByStaleChromeSnapshot() async {
        let name = "audit-stale-chrome-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let inner = InMemoryCalendarService(grantAccessByDefault: true)
        let calendar = GatedCalendarService(inner: inner)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: defaults)
        viewModel.title = "切换日历竞态"
        viewModel.reviewIntervals = [3]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()

        let entered = expectation(description: "create entered")
        calendar.onEnterCreate = { entered.fulfill() }
        let task = Task { await viewModel.createReviewSchedule() }
        await fulfillment(of: [entered], timeout: 5)

        viewModel.selectedCalendarIdentifier = "outlook-default"
        XCTAssertEqual(defaults.string(forKey: "selectedCalendarIdentifier"), "outlook-default")

        calendar.openGate()
        await task.value

        XCTAssertEqual(
            defaults.string(forKey: "selectedCalendarIdentifier"),
            "outlook-default",
            "create 返回后的旧快照把用户新选的日历写回默认值"
        )
    }
}

@MainActor
final class DuplicateDayHistoryTests: XCTestCase {
    func testDuplicateDayEntryKeepsStaleIdentifierForUnrecordedDay() async throws {
        let name = "audit-duplicate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "重复日"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3]
        session.updateReviewDates()
        await session.create()
        XCTAssertEqual(session.resultType, .success)

        session.title = "重复日"
        session.reviewIntervals = [3, 7]
        session.updateReviewDates()
        await session.create()
        XCTAssertEqual(session.resultType, .warning)

        let entry = try XCTUnwrap(history.load().first)
        XCTAssertEqual(
            entry.liveEventIdentifiers.count,
            entry.reviewDates.count,
            "历史保存的 id 数量与记录的复习日期数量应一致"
        )
    }
}

@MainActor
final class DuplicateWarningUndoTests: XCTestCase {
    func testUndoAfterDuplicateWarningDeletesPreviousBatchEvent() async {
        let name = "audit-dup-undo-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let calendar = InMemoryCalendarService(grantAccessByDefault: true)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "重复撤销"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3]
        session.updateReviewDates()
        await session.create()
        let firstBatchIDs = Set(history.load().first!.createdEventIdentifiers)

        session.title = "重复撤销"
        session.reviewIntervals = [3, 7]
        session.updateReviewDates()
        await session.create()
        XCTAssertEqual(session.resultType, .warning)

        await session.undo()

        let remaining = calendar.fetchEvents(
            from: Date().addingTimeInterval(-86_400),
            to: Date().addingTimeInterval(86_400 * 40)
        )
        let survivorIDs = Set(remaining.map(\.id))
        XCTAssertTrue(
            firstBatchIDs.isSubset(of: survivorIDs),
            "撤销第二次创建时把第一次批次的复习事件一并删除了"
        )
    }
}

@MainActor
final class CreateInFlightTitleTests: XCTestCase {
    func testTitleChangeDuringCreateRecordsWrongTitleAndLosesSeriesLink() async throws {
        let name = "audit-title-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let inner = InMemoryCalendarService(grantAccessByDefault: true)
        let calendar = GatedCalendarService(inner: inner)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: defaults)
        viewModel.title = "原标题"
        viewModel.reviewIntervals = [3, 7]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()

        let entered = expectation(description: "create entered")
        calendar.onEnterCreate = { entered.fulfill() }
        let task = Task { await viewModel.createReviewSchedule() }
        await fulfillment(of: [entered], timeout: 5)
        viewModel.title = "后改标题"
        calendar.openGate()
        await task.value

        let entry = try XCTUnwrap(HistoryStore(defaults: defaults).load().first)
        XCTAssertEqual(entry.title, "原标题", "历史标题应记录实际写入日历的标题")

        let events = inner.fetchEvents(
            from: Date().addingTimeInterval(-86_400),
            to: Date().addingTimeInterval(86_400 * 40)
        )
        XCTAssertTrue(events.allSatisfy { $0.title == "原标题" })
        let matched = HistorySeriesLookup.entry(matching: events[0], in: [entry])
        XCTAssertNotNil(matched, "标题不一致后属性兜底匹配失效，系列无法再被识别")
    }

    func testScheduleModeChangeDuringCreateRecordsSingleInsteadOfReview() async throws {
        let name = "audit-mode-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let inner = InMemoryCalendarService(grantAccessByDefault: true)
        let calendar = GatedCalendarService(inner: inner)
        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let session = ReviewSession(calendar: calendar, outcomes: outcomes)

        session.title = "模式竞态"
        session.baseDate = Date()
        session.scheduleMode = .review
        session.reviewIntervals = [3, 7]
        session.updateReviewDates()

        let entered = expectation(description: "create entered")
        calendar.onEnterCreate = { entered.fulfill() }
        let task = Task { await session.create() }
        await fulfillment(of: [entered], timeout: 5)
        session.scheduleMode = .single
        calendar.openGate()
        await task.value

        let entry = try XCTUnwrap(history.load().first)
        XCTAssertEqual(entry.type, .review, "实际写了三条复习事件，历史却被记成单次")
        let ids = entry.createdEventIdentifiers
        XCTAssertTrue(
            ids.allSatisfy { session.canMarkOccurrence(eventId: $0) },
            "历史被记成 single 后，系列成员永久无法标记完成"
        )
    }
}

@MainActor
final class TypingLostToStaleChromeTests: XCTestCase {
    func testTitleTypedDuringCreateIsErasedByStaleSnapshot() async {
        let name = "audit-typing-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let inner = InMemoryCalendarService(grantAccessByDefault: true)
        let calendar = GatedCalendarService(inner: inner)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: defaults)
        viewModel.title = "第一批"
        viewModel.reviewIntervals = [3]
        viewModel.scheduleMode = .review
        viewModel.updateReviewDates()

        let entered = expectation(description: "create entered")
        calendar.onEnterCreate = { entered.fulfill() }
        let task = Task { await viewModel.createReviewSchedule() }
        await fulfillment(of: [entered], timeout: 5)

        viewModel.title = "用户正在输入的第二批标题"
        viewModel.detail = "用户正在输入的详情"
        calendar.openGate()
        await task.value

        XCTAssertEqual(
            viewModel.title,
            "用户正在输入的第二批标题",
            "create 返回后 pullSessionChrome 用旧快照抹掉了用户正在输入的内容"
        )
        XCTAssertEqual(
            viewModel.detail,
            "用户正在输入的详情",
            "详情同样被旧快照抹掉"
        )
    }
}

@MainActor
final class WeekendMigrationMarkerTests: XCTestCase {
    func testWeekendMigrationMarkerIsNotBurnedWhenWeeklyPayloadIsCorrupt() {
        let name = "audit-weekend-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: WeeklyReviewViewModel.historyMigrationKey)
        defaults.set("[{\"id\":\"oops\"}]", forKey: WeeklyReviewViewModel.weeklyEntriesKey)

        _ = WeeklyReviewViewModel(defaults: defaults)

        XCTAssertFalse(
            defaults.bool(forKey: WeeklyReviewViewModel.weekendMigrationKey),
            "周回顾条目解码失败时不应标记周末占位迁移完成"
        )
    }
}

@MainActor
final class HistoryCapOrphanTests: XCTestCase {
    func testDroppedHistoryEntryLeavesOrphanWeeklyEntryAndStatus() {
        let name = "audit-cap-orphan-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let history = HistoryStore(defaults: defaults)
        let weekly = WeeklyReviewViewModel(defaults: defaults)
        let statuses = OccurrenceStatusStore(defaults: defaults)
        let outcomes = CreateSuccessOutcomes(
            history: history,
            weekly: weekly,
            occurrenceStatuses: statuses
        )

        var firstBatchID: UUID?
        for index in 0..<22 {
            let entry = HistoryEntry(
                title: "批次\(index)",
                baseDate: Date(),
                reviewDates: [],
                creationDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                type: .review,
                createdEventIdentifiers: ["evt-\(index)"]
            )
            if index == 0 { firstBatchID = entry.id }
            outcomes.record(entry)
            statuses.setStatus(.done, for: "evt-\(index)")
        }

        let dropped = try! XCTUnwrap(firstBatchID)
        XCTAssertFalse(history.load().contains(where: { $0.id == dropped }))
        XCTAssertFalse(
            weekly.weeklyEntries.contains(where: { $0.id == dropped }),
            "历史被裁掉时周回顾里对应条目应一并清掉，避免两处数据不一致"
        )
        XCTAssertFalse(
            statuses.markedEntries().keys.contains("evt-0"),
            "历史被裁掉后其完成标记应一并清理，避免永久孤儿"
        )
    }
}

@MainActor
final class CalendarSelectionBeforeAccessTests: XCTestCase {
    func testStoredCalendarChoiceIsNotSilentlyDroppedBeforeAccessIsGranted() {
        let name = "audit-selection-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("outlook-default", forKey: "selectedCalendarIdentifier")

        let calendar = InMemoryCalendarService(grantAccessByDefault: false)
        let viewModel = ReviewViewModel(calendar: calendar, defaults: defaults)

        XCTAssertEqual(
            viewModel.selectedCalendarIdentifier,
            "outlook-default",
            "授权未就绪时把已保存的日历选择清空，之后的写入会静默落到默认日历"
        )
        XCTAssertEqual(defaults.string(forKey: "selectedCalendarIdentifier"), "outlook-default")
    }
}
