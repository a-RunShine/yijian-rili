import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
class ReviewViewModel: ObservableObject {
    typealias ResultType = ReviewSession.ResultType
    typealias ScheduleMode = ReviewSession.ScheduleMode
    typealias DayType = DayBrowseModel.DayType

    enum MainSegment: String, CaseIterable, Identifiable {
        case create
        case today
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .create: return NSLocalizedString("segment_create", comment: "")
            case .today: return NSLocalizedString("segment_today", comment: "")
            case .settings: return NSLocalizedString("segment_settings", comment: "")
            }
        }
    }

    let session: ReviewSession
    let browse: DayBrowseModel
    let historyStore: HistoryStore
    private let calendar: CalendarService
    private let outcomes: CreateSuccessOutcomes

    @Published var selectedSegment: MainSegment = .create
    @Published var title: String = "" {
        didSet { session.title = title }
    }
    @Published var detail: String = "" {
        didSet { session.detail = detail }
    }
    @Published var baseDate: Date = Date() {
        didSet {
            let start = Calendar.current.startOfDay(for: baseDate)
            if baseDate != start {
                baseDate = start
                return
            }
            session.baseDate = start
            if !keepVisibleMonth {
                visibleMonth = Self.monthStart(for: start)
            }
        }
    }
    private var keepVisibleMonth = false
    private var loadedWindowStart: Date?
    private var loadedWindowEnd: Date?
    @Published private(set) var visibleMonth: Date = ReviewViewModel.monthStart(for: Date())
    @Published private(set) var eventsByDay: [Date: [CalendarEventInfo]] = [:]
    @Published var customIntervalDraft: String = ""
    @Published var sharedDetailDraft: String = ""
    @Published var seriesTitleDraft: String = ""
    @Published var editingSharedDetailEntryID: UUID?
    @Published var browseSharedDetailUnavailableEvent: CalendarEventInfo?
    @Published var sharedDetailEditOutcomeVisible: Bool = false
    @Published var sharedDetailResultOnToday: Bool = false
    @Published var reviewDates: [Date] = []
    @Published var authorizationStatus: CalendarAccessStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var resultMessage: String?
    @Published var resultType: ResultType?
    @Published var canUndo: Bool = false
    @Published var canRecreate: Bool = false
    @Published var showHistory: Bool = false
    @Published var showFirstRunGuide: Bool = false
    @Published var showHelpGuide: Bool = false
    @Published var showSearch: Bool = false
    @Published var searchText: String = "" {
        didSet { browse.searchText = searchText }
    }
    @Published var searchResults: [CalendarEventInfo] = []
    @Published var searchHits: [SearchHit] = []
    @Published var selectedSearchResult: CalendarEventInfo? {
        didSet { browse.selectedSearchResult = selectedSearchResult }
    }
    @Published var selectedSearchHit: SearchHit?
    @Published var seriesPendingDelete: SearchHit?
    @Published var displayedEvents: [CalendarEventInfo] = []
    @Published var displayedDayHits: [SearchHit] = []
    @Published var historySearchText: String = ""
    @Published var scheduleMode: ScheduleMode = .review {
        didSet {
            session.scheduleMode = scheduleMode
            if scheduleMode != oldValue {
                updateReviewDates()
            }
        }
    }
    @Published var currentTheme: Theme = {
        let rawValue = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: rawValue) ?? .light
    }()

    @Published var availableCalendars: [CalendarInfo] = []
    @Published var hasCloudCalendar: Bool = false

    @Published private(set) var historyRevision: Int = 0
    @Published private(set) var occurrenceRevision: Int = 0

    @AppStorage("selectedCalendarIdentifier") var selectedCalendarIdentifier: String = "" {
        didSet {
            session.selectedCalendarIdentifier = selectedCalendarIdentifier
            session.persistSelectedCalendar()
        }
    }
    @AppStorage("hasShownFirstRunGuide") private var hasShownFirstRunGuide: Bool = false
    @AppStorage("calendarPickerExpanded") var calendarPickerExpanded: Bool = false
    @AppStorage("windowSettingsExpanded") var windowSettingsExpanded: Bool = false

    @Published var reviewIntervals: [Int] = IntervalRules.defaultIntervals {
        didSet {
            session.reviewIntervals = reviewIntervals
            session.persistIntervals()
        }
    }

    @Published var customPresets: [CustomPreset] = [] {
        didSet {
            session.customPresets = customPresets
            session.persistCustomPresets()
        }
    }

    var historyEntries: [HistoryEntry] {
        _ = historyRevision
        return historyStore.load()
    }

    private var notificationToken: Any?
    private var activeToken: Any?
    private var resultDismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var selectedCalendar: CalendarInfo? { session.selectedCalendar }
    var isSelectedCalendarLocal: Bool { session.isSelectedCalendarLocal }
    var selectedCalendarDisplayName: String { session.selectedCalendarDisplayName }

    init(calendar: CalendarService = CalendarManager.shared) {
        self.calendar = calendar
        let history = HistoryStore()
        let weekly = WeeklyReviewViewModel()
        let outcomes = CreateSuccessOutcomes(history: history, weekly: weekly)
        let occurrenceStatuses = OccurrenceStatusStore()
        self.historyStore = history
        self.weeklyReviewViewModel = weekly
        self.outcomes = outcomes

        let storedCalendarId = UserDefaults.standard.string(forKey: "selectedCalendarIdentifier") ?? ""
        let session = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            occurrenceStatuses: occurrenceStatuses,
            selectedCalendarIdentifier: storedCalendarId
        )
        self.session = session
        weekly.occurrenceMaterialProvider = { start, end in
            session.occurrenceMaterials(weekStart: start, weekEnd: end)
        }
        self.browse = DayBrowseModel(calendar: calendar)

        title = session.title
        detail = session.detail
        let start = Calendar.current.startOfDay(for: session.baseDate)
        baseDate = start
        session.baseDate = start
        visibleMonth = Self.monthStart(for: start)
        reviewDates = session.reviewDates
        scheduleMode = session.scheduleMode
        reviewIntervals = session.reviewIntervals
        customPresets = session.customPresets
        selectedCalendarIdentifier = session.selectedCalendarIdentifier
        pullSessionChrome()
        pullBrowseState()
        updateReviewDates()
        if authorizationStatus == .fullAccess {
            loadVisibleWindow()
        }

        if let manager = calendar as? CalendarManager {
            manager.$availableCalendars
                .receive(on: DispatchQueue.main)
                .sink { [weak self] calendars in
                    self?.availableCalendars = calendars
                    self?.session.availableCalendars = calendars
                }
                .store(in: &cancellables)
            manager.$hasCloudCalendar
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.hasCloudCalendar = value
                    self?.session.hasCloudCalendar = value
                }
                .store(in: &cancellables)
            manager.$authorizationStatus
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.authorizationStatus = status
                    self?.session.authorizationStatus = status
                }
                .store(in: &cancellables)
        }

        notificationToken = NotificationCenter.default.addObserver(
            forName: .createReviewSchedule,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.createReviewSchedule() }
        }

        activeToken = NotificationCenter.default.addObserver(
            forName: .appDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.session.refreshCalendars()
                self.pullSessionChrome()
                if self.authorizationStatus == .fullAccess {
                    self.loadDisplayedDayEvents()
                    self.loadVisibleWindow()
                }
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.authorizationStatus == .notDetermined {
                let granted = await self.session.requestAccessIfNeeded()
                self.pullSessionChrome()
                if granted {
                    self.loadDisplayedDayEvents()
                    self.loadVisibleWindow()
                }
            } else if self.authorizationStatus == .fullAccess {
                self.loadDisplayedDayEvents()
                self.loadVisibleWindow()
            }
        }
    }

    @MainActor
    deinit {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = activeToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private func pullSessionChrome() {
        authorizationStatus = session.authorizationStatus
        availableCalendars = session.availableCalendars
        hasCloudCalendar = session.hasCloudCalendar
        isLoading = session.isLoading
        resultMessage = session.resultMessage
        resultType = session.resultType
        canUndo = session.canUndo
        canRecreate = session.canRecreate
        reviewDates = session.reviewDates
        title = session.title
        detail = session.detail
        baseDate = session.baseDate
        selectedCalendarIdentifier = session.selectedCalendarIdentifier
    }

    private func pullBrowseState() {
        displayedEvents = browse.displayedEvents
        searchResults = browse.searchResults
        selectedSearchResult = browse.selectedSearchResult
        searchText = browse.searchText
        selectedDayType = browse.selectedDayType
        rebuildSearchHits()
        rebuildDisplayedDayHits()
    }

    private func rebuildSearchHits() {
        reconcileRecordedWithCalendar()
        _ = historyRevision
        searchHits = SearchCollapse.collapse(
            rawHits: browse.searchResults,
            history: historyStore.load(),
            eventById: { [calendar] id in calendar.event(withId: id) }
        )
        if let selected = selectedSearchHit,
           !searchHits.contains(where: { $0.id == selected.id }) {
            selectedSearchHit = nil
            selectedSearchResult = nil
        }
    }

    private func rebuildDisplayedDayHits() {
        _ = historyRevision
        displayedDayHits = projectedDayHits(browse.displayedEvents)
    }

    private func projectedDayHits(_ dayEvents: [CalendarEventInfo]) -> [SearchHit] {
        DayEventProjection.project(
            dayEvents: dayEvents,
            history: historyStore.load(),
            eventById: { [calendar] id in calendar.event(withId: id) }
        )
    }

    func projectedHit(forEventId eventId: String, on day: Date) -> SearchHit? {
        _ = historyRevision
        let start = Calendar.current.startOfDay(for: day)
        let dayEvents = eventsByDay[start] ?? []
        guard let event = dayEvents.first(where: { $0.id == eventId })
            ?? calendar.event(withId: eventId) else {
            return nil
        }
        return projectedDayHits([event]).first
    }

    private func pushInputsToSession() {
        session.title = title
        session.detail = detail
        session.baseDate = baseDate
        session.scheduleMode = scheduleMode
        session.reviewIntervals = reviewIntervals
        session.customPresets = customPresets
        session.selectedCalendarIdentifier = selectedCalendarIdentifier
    }

    func updateReviewDates() {
        pushInputsToSession()
        session.updateReviewDates()
        reviewDates = session.reviewDates
    }

    func selectDay(_ day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        if Self.monthStart(for: start) == visibleMonth {
            reselectWithinVisibleMonth(start)
        } else {
            baseDate = start
            updateReviewDates()
        }
        loadVisibleWindowIfNeeded()
    }

    func moveSelection(to day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        guard start != baseDate else { return }
        reselectWithinVisibleMonth(start)
    }

    private func reselectWithinVisibleMonth(_ start: Date) {
        keepVisibleMonth = true
        baseDate = start
        keepVisibleMonth = false
        updateReviewDates()
    }

    func goToToday(now: Date = Date()) {
        selectDay(now)
    }

    func shiftVisibleMonth(by months: Int) {
        let calendar = Calendar.current
        guard let shifted = calendar.date(byAdding: .month, value: months, to: visibleMonth) else { return }
        visibleMonth = Self.monthStart(for: shifted)
        loadVisibleWindow()
    }

    private func loadVisibleWindow() {
        loadedWindowStart = nil
        loadedWindowEnd = nil
        loadVisibleWindowIfNeeded()
    }

    private func loadVisibleWindowIfNeeded() {
        let cells = MonthGrid.cells(in: visibleMonth, today: Date())
        guard let first = cells.first?.date, let last = cells.last?.date else {
            eventsByDay = [:]
            loadedWindowStart = nil
            loadedWindowEnd = nil
            return
        }
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: last) else {
            eventsByDay = [:]
            loadedWindowStart = nil
            loadedWindowEnd = nil
            return
        }
        if loadedWindowStart == first, loadedWindowEnd == end {
            return
        }
        eventsByDay = CalendarEventGrouping.byDay(calendar.fetchEvents(from: first, to: end))
        loadedWindowStart = first
        loadedWindowEnd = end
    }

    private static func monthStart(for day: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month], from: day)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: day)
    }

    func createReviewSchedule() async {
        if let failure = commitPendingIntervalDraft() {
            presentSubmitError(Self.intervalDraftMessage(failure))
            return
        }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            presentSubmitError(NSLocalizedString("empty_title_error", comment: ""))
            return
        }
        pushInputsToSession()
        await session.create()
        pullSessionChrome()
        if session.consumeHapticFlag() {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        if session.resultType == .success || session.resultType == .warning {
            refreshHistoryProjection()
            loadDisplayedDayEvents()
            loadVisibleWindow()
        }
        scheduleResultDismissal()
    }

    private func commitPendingIntervalDraft() -> IntervalDraftFailure? {
        guard let tokens = pendingIntervalTokens() else { return nil }
        switch commitIntervalDraft(tokens) {
        case .success:
            return nil
        case .failure(let failure):
            return failure
        }
    }

    private func pendingIntervalTokens() -> [String]? {
        let trimmed = customIntervalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let separators = CharacterSet(charactersIn: ",，、").union(.whitespacesAndNewlines)
        let tokens = trimmed.components(separatedBy: separators).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        if case .success(let parsed) = IntervalRules.parseDraft(tokens), parsed == reviewIntervals {
            return nil
        }
        return tokens
    }

    private func presentSubmitError(_ message: String) {
        resultMessage = message
        resultType = .error
        session.resultMessage = message
        session.resultType = .error
    }

    private static func intervalDraftMessage(_ failure: IntervalDraftFailure) -> String {
        switch failure {
        case .empty:
            return NSLocalizedString("interval_min_error", comment: "")
        case .tooMany:
            return NSLocalizedString("interval_max_error", comment: "")
        case .invalidAt(let index):
            return String(format: NSLocalizedString("interval_invalid_at", comment: ""), "\(index)")
        case .notIncreasingAt(let index):
            return String(format: NSLocalizedString("interval_not_increasing_at", comment: ""), "\(index)")
        }
    }

    func undoReviewSchedule() async {
        await session.undo()
        pullSessionChrome()
        refreshHistoryProjection()
        loadDisplayedDayEvents()
        loadVisibleWindow()
        weeklyReviewViewModel.refreshOccurrenceMaterials()
        scheduleResultDismissal()
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    @Published var selectedDayType: DayType = .today {
        didSet { browse.selectedDayType = selectedDayType }
    }

    var displayedDate: Date { browse.displayedDate }

    func date(for dayType: DayType) -> Date {
        browse.date(for: dayType)
    }

    func loadDisplayedDayEvents() {
        reconcileRecordedWithCalendar()
        browse.loadDisplayedDayEvents()
        displayedEvents = browse.displayedEvents
        rebuildDisplayedDayHits()
    }

    func selectDayType(_ dayType: DayType) {
        reconcileRecordedWithCalendar()
        browse.selectDayType(dayType)
        selectedDayType = browse.selectedDayType
        displayedEvents = browse.displayedEvents
        rebuildDisplayedDayHits()
    }

    private func scheduleResultDismissal() {
        resultDismissTask?.cancel()
        guard resultType == .success || resultType == .warning else { return }
        resultDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.resultMessage = nil
                self?.resultType = nil
                self?.session.resultMessage = nil
                self?.session.resultType = nil
                self?.sharedDetailResultOnToday = false
                if self?.sharedDetailEditOutcomeVisible == true {
                    self?.finishSharedDetailEditSheet()
                }
            }
        }
    }

    func recreateLastSchedule() {
        session.recreateLastSchedule()
        pullSessionChrome()
        canRecreate = session.canRecreate
    }

    private func refreshHistoryProjection() {
        historyRevision &+= 1
    }

    private func reconcileRecordedWithCalendar() {
        if session.reconcileRecordedWithCalendar() {
            refreshHistoryProjection()
        }
    }

    let weeklyReviewViewModel: WeeklyReviewViewModel

    @Published var showWeeklyReview: Bool = false

    func openWeeklyReview() {
        weeklyReviewViewModel.jumpToCurrentWeek()
        weeklyReviewViewModel.refreshOccurrenceMaterials()
        showWeeklyReview = true
    }

    func occurrenceStatus(for eventId: String) -> OccurrenceStatus {
        _ = occurrenceRevision
        return session.occurrenceStatus(for: eventId)
    }

    func setOccurrenceStatus(eventId: String, status: OccurrenceStatus) {
        session.setOccurrenceStatus(eventId: eventId, status: status)
        occurrenceRevision &+= 1
        weeklyReviewViewModel.refreshOccurrenceMaterials()
    }

    func selectHistoryEntry(_ entry: HistoryEntry) {
        session.selectHistoryEntry(entry)
        pullSessionChrome()
        updateReviewDates()
        showHistory = false
        loadVisibleWindowIfNeeded()
    }

    var todayCreatedEntries: [HistoryEntry] {
        reconcileRecordedWithCalendar()
        _ = historyRevision
        return session.todayCreatedEntries()
    }

    var editingSharedDetailEntry: HistoryEntry? {
        guard let editingSharedDetailEntryID else { return nil }
        return historyEntries.first(where: { $0.id == editingSharedDetailEntryID })
    }

    var canEditSharedDetailForSelection: Bool {
        guard browseSharedDetailUnavailableEvent == nil else { return false }
        guard let entry = editingSharedDetailEntry else { return false }
        return !entry.createdEventIdentifiers.isEmpty
    }

    var isSharedDetailSheetPresented: Bool {
        editingSharedDetailEntryID != nil || browseSharedDetailUnavailableEvent != nil
    }

    var modalSheetPresented: Bool {
        showFirstRunGuide
            || showHelpGuide
            || showSearch
            || showWeeklyReview
            || isSharedDetailSheetPresented
            || seriesPendingDelete != nil
    }

    func beginSharedDetailEdit(for entry: HistoryEntry) {
        sharedDetailEditOutcomeVisible = false
        sharedDetailResultOnToday = false
        browseSharedDetailUnavailableEvent = nil
        if showHistory {
            showHistory = false
        }
        editingSharedDetailEntryID = entry.id
        seriesTitleDraft = entry.title
        sharedDetailDraft = entry.sharedDetail ?? ""
    }

    func beginSharedDetailEditFromBrowse(_ event: CalendarEventInfo, on day: Date) {
        let target = projectedHit(forEventId: event.id, on: day)?.focusedEvent ?? event
        beginSharedDetailEditFromBrowse(target)
    }

    func beginSharedDetailEditFromBrowse(_ event: CalendarEventInfo) {
        sharedDetailEditOutcomeVisible = false
        sharedDetailResultOnToday = false
        if showHistory {
            showHistory = false
        }
        if let entry = HistorySeriesLookup.entry(containingEventId: event.id, in: historyEntries) {
            browseSharedDetailUnavailableEvent = nil
            editingSharedDetailEntryID = entry.id
            seriesTitleDraft = entry.title
            let fromHistory = (entry.sharedDetail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if fromHistory.isEmpty {
                sharedDetailDraft = NotesDetail.extract(event.notes)
            } else {
                sharedDetailDraft = entry.sharedDetail ?? ""
            }
        } else {
            editingSharedDetailEntryID = nil
            browseSharedDetailUnavailableEvent = event
            seriesTitleDraft = event.title
            sharedDetailDraft = NotesDetail.extract(event.notes)
        }
    }

    func cancelSharedDetailEdit() {
        let hadOutcome = sharedDetailEditOutcomeVisible
        finishSharedDetailEditSheet()
        if hadOutcome {
            sharedDetailResultOnToday = resultMessage != nil
            scheduleResultDismissal()
        }
    }

    func dismissSharedDetailEditAfterOutcome() {
        sharedDetailEditOutcomeVisible = false
        finishSharedDetailEditSheet()
        sharedDetailResultOnToday = resultMessage != nil
        scheduleResultDismissal()
    }

    private func finishSharedDetailEditSheet() {
        editingSharedDetailEntryID = nil
        browseSharedDetailUnavailableEvent = nil
        sharedDetailDraft = ""
        seriesTitleDraft = ""
        sharedDetailEditOutcomeVisible = false
    }

    @discardableResult
    func commitSharedDetailEdit() -> SharedDetailUpdateOutcome {
        guard let entry = editingSharedDetailEntry else { return .unavailable }
        let trimmedTitle = seriesTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleChanged = !trimmedTitle.isEmpty && trimmedTitle != entry.title
        let detailOutcome = updateSharedDetail(for: entry, detail: sharedDetailDraft)
        var outcome = detailOutcome
        if titleChanged {
            let refreshed = editingSharedDetailEntry ?? entry
            outcome = updateSeriesTitle(for: refreshed, title: seriesTitleDraft)
        }
        sharedDetailEditOutcomeVisible = true
        sharedDetailResultOnToday = false
        scheduleResultDismissal()
        return outcome
    }

    @discardableResult
    func updateSharedDetail(for entry: HistoryEntry, detail: String) -> SharedDetailUpdateOutcome {
        let outcome = session.updateSharedDetail(for: entry, detail: detail)
        pullSessionChrome()
        if case .updated = outcome {
            refreshHistoryProjection()
            loadDisplayedDayEvents()
        }
        return outcome
    }

    @discardableResult
    func updateSeriesTitle(for entry: HistoryEntry, title: String) -> SharedDetailUpdateOutcome {
        let outcome = session.updateSeriesTitle(for: entry, title: title)
        pullSessionChrome()
        if case .updated(let updated, _) = outcome, updated > 0 {
            refreshHistoryProjection()
            loadDisplayedDayEvents()
            rebuildSearchHits()
        }
        return outcome
    }

    func clearHistory() {
        outcomes.clearHistory()
        refreshHistoryProjection()
    }

    func deleteHistoryEntry(_ entry: HistoryEntry) {
        outcomes.removeHistory(id: entry.id)
        refreshHistoryProjection()
    }

    func deleteHistoryEntry(at offsets: IndexSet) {
        let entries = historyEntries
        for index in offsets {
            guard entries.indices.contains(index) else { continue }
            outcomes.removeHistory(id: entries[index].id)
        }
        refreshHistoryProjection()
    }

    var filteredHistoryEntries: [HistoryEntry] {
        historyStore.filter(historySearchText)
    }

    func applyPreset(_ preset: IntervalPreset) {
        session.applyPreset(preset)
        reviewIntervals = session.reviewIntervals
        reviewDates = session.reviewDates
    }

    func resetIntervalsToDefault() {
        session.resetIntervalsToDefault()
        reviewIntervals = session.reviewIntervals
        reviewDates = session.reviewDates
    }

    @discardableResult
    func commitIntervalDraft(_ draft: [String]) -> Result<[Int], IntervalDraftFailure> {
        let result = session.commitIntervalDraft(draft)
        if case .success = result {
            reviewIntervals = session.reviewIntervals
            reviewDates = session.reviewDates
        }
        return result
    }

    func saveCustomPreset(name: String) {
        session.reviewIntervals = reviewIntervals
        session.saveCustomPreset(name: name)
        customPresets = session.customPresets
    }

    func applyCustomPreset(_ preset: CustomPreset) {
        session.applyCustomPreset(preset)
        reviewIntervals = session.reviewIntervals
        reviewDates = session.reviewDates
    }

    func deleteCustomPreset(id: UUID) {
        session.deleteCustomPreset(id: id)
        customPresets = session.customPresets
    }

    func hasDuplicatePresetName(_ name: String) -> Bool {
        session.hasDuplicatePresetName(name)
    }

    @Published var windowFloating: Bool = UserDefaults.standard.object(forKey: "windowFloating") as? Bool ?? true {
        didSet { UserDefaults.standard.set(windowFloating, forKey: "windowFloating") }
    }

    func applyWindowLevel() {
        let level: NSWindow.Level = windowFloating ? .floating : .normal
        NSApp.windows.forEach { $0.level = level }
    }

    func scheduleFirstRunGuideIfNeeded() {
        guard !hasShownFirstRunGuide else { return }
        guard authorizationStatus == .fullAccess else { return }
        guard !hasCloudCalendar else { return }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            guard !self.hasShownFirstRunGuide, !self.hasCloudCalendar else { return }
            self.showFirstRunGuide = true
        }
    }

    func dismissFirstRunGuide() {
        showFirstRunGuide = false
        hasShownFirstRunGuide = true
    }

    func openHelpGuide() {
        showHelpGuide = true
    }

    func setTheme(_ theme: Theme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
        UserDefaults.standard.set(theme.rawValue, forKey: "themeName")
    }

    func performSearch() {
        browse.searchText = searchText
        browse.performSearch()
        searchResults = browse.searchResults
        rebuildSearchHits()
    }

    @discardableResult
    func deleteSearchResult(_ event: CalendarEventInfo) -> Bool {
        deleteSearchHit(
            SearchHit(
                id: event.id,
                kind: .single,
                title: event.title,
                members: [event]
            )
        )
    }

    @discardableResult
    func deleteSearchHit(_ hit: SearchHit) -> Bool {
        guard !hit.needsSelectiveDelete else { return false }
        guard let event = hit.members.first else { return false }
        let success = browse.deleteSearchResult(event)
        searchResults = browse.searchResults
        selectedSearchResult = browse.selectedSearchResult
        displayedEvents = browse.displayedEvents
        if success {
            applyDeletedEvents(ids: [event.id])
            if selectedSearchHit?.id == hit.id {
                selectedSearchHit = nil
            }
        }
        return success
    }

    @discardableResult
    func deleteSearchHitMembers(ids: [String]) -> (deletedCount: Int, missingCount: Int) {
        let outcome = browse.deleteEvents(ids: ids)
        searchResults = browse.searchResults
        selectedSearchResult = browse.selectedSearchResult
        displayedEvents = browse.displayedEvents
        if outcome.deletedCount > 0 {
            applyDeletedEvents(ids: ids)
            if let selected = selectedSearchHit,
               selected.members.contains(where: { ids.contains($0.id) }) {
                selectedSearchHit = searchHits.first(where: { $0.id == selected.id })
                selectedSearchResult = selectedSearchHit?.representative
            }
        }
        seriesPendingDelete = nil
        return outcome
    }

    private func applyDeletedEvents(ids: [String]) {
        session.removeEventsFromRecorded(ids: ids)
        refreshHistoryProjection()
        rebuildSearchHits()
        rebuildDisplayedDayHits()
        loadVisibleWindow()
        weeklyReviewViewModel.refreshOccurrenceMaterials()
    }

    func beginSeriesDelete(_ hit: SearchHit) {
        guard hit.needsSelectiveDelete else { return }
        seriesPendingDelete = hit
    }

    func selectSearchHit(_ hit: SearchHit) {
        selectedSearchHit = hit
        selectedSearchResult = hit.representative
        browse.selectedSearchResult = hit.representative
    }

    func clearSearchSelection() {
        selectedSearchHit = nil
        selectedSearchResult = nil
        browse.selectedSearchResult = nil
    }

    func resetSearch() {
        browse.resetSearch()
        selectedSearchHit = nil
        seriesPendingDelete = nil
        pullBrowseState()
    }
}

struct CustomPreset: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let intervals: [Int]

    init(id: UUID = UUID(), name: String, intervals: [Int]) {
        self.id = id
        self.name = name
        self.intervals = intervals
    }
}

enum IntervalPreset: String, CaseIterable {
    case classic
    case exam
    case daily

    var displayName: String {
        switch self {
        case .classic: return NSLocalizedString("preset_classic", comment: "")
        case .exam: return NSLocalizedString("preset_exam", comment: "")
        case .daily: return NSLocalizedString("preset_daily", comment: "")
        }
    }

    var intervals: [Int] {
        switch self {
        case .classic: return [1, 2, 4, 7, 15]
        case .exam: return [1, 3, 7]
        case .daily: return [3, 7, 30]
        }
    }
}

extension Notification.Name {
    static let createReviewSchedule = Notification.Name("createReviewSchedule")
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let toggleCanvas = Notification.Name("toggleCanvas")
    static let focusComposerTitle = Notification.Name("focusComposerTitle")
    static let openComposer = Notification.Name("openComposer")
    static let newComposer = Notification.Name("newComposer")
    static let dismissTopPanel = Notification.Name("dismissTopPanel")
}
