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
        didSet { session.baseDate = baseDate }
    }
    @Published var sharedDetailDraft: String = ""
    @Published var editingSharedDetailEntryID: UUID?
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
    @Published var selectedSearchResult: CalendarEventInfo? {
        didSet { browse.selectedSearchResult = selectedSearchResult }
    }
    @Published var displayedEvents: [CalendarEventInfo] = []
    @Published var historySearchText: String = ""
    @Published var scheduleMode: ScheduleMode = .review {
        didSet { session.scheduleMode = scheduleMode }
    }
    @Published var currentTheme: Theme = {
        let rawValue = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: rawValue) ?? .light
    }()

    @Published var availableCalendars: [CalendarInfo] = []
    @Published var hasCloudCalendar: Bool = false

    @Published private(set) var historyRevision: Int = 0

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
        self.historyStore = history
        self.weeklyReviewViewModel = weekly
        self.outcomes = outcomes

        let storedCalendarId = UserDefaults.standard.string(forKey: "selectedCalendarIdentifier") ?? ""
        self.session = ReviewSession(
            calendar: calendar,
            outcomes: outcomes,
            selectedCalendarIdentifier: storedCalendarId
        )
        self.browse = DayBrowseModel(calendar: calendar)

        title = session.title
        detail = session.detail
        baseDate = session.baseDate
        reviewDates = session.reviewDates
        scheduleMode = session.scheduleMode
        reviewIntervals = session.reviewIntervals
        customPresets = session.customPresets
        selectedCalendarIdentifier = session.selectedCalendarIdentifier
        pullSessionChrome()
        pullBrowseState()

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
                }
            }
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.authorizationStatus == .notDetermined {
                let granted = await self.session.requestAccessIfNeeded()
                self.pullSessionChrome()
                if granted { self.loadDisplayedDayEvents() }
            } else if self.authorizationStatus == .fullAccess {
                self.loadDisplayedDayEvents()
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

    func createReviewSchedule() async {
        pushInputsToSession()
        await session.create()
        pullSessionChrome()
        if session.consumeHapticFlag() {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        if session.resultType == .success {
            refreshHistoryProjection()
            loadDisplayedDayEvents()
        }
        scheduleResultDismissal()
    }

    func undoReviewSchedule() async {
        await session.undo()
        pullSessionChrome()
        refreshHistoryProjection()
        loadDisplayedDayEvents()
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
        browse.loadDisplayedDayEvents()
        displayedEvents = browse.displayedEvents
    }

    func selectDayType(_ dayType: DayType) {
        browse.selectDayType(dayType)
        selectedDayType = browse.selectedDayType
        displayedEvents = browse.displayedEvents
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

    let weeklyReviewViewModel: WeeklyReviewViewModel

    @Published var showWeeklyReview: Bool = false

    func openWeeklyReview() {
        weeklyReviewViewModel.jumpToCurrentWeek()
        showWeeklyReview = true
    }

    func selectHistoryEntry(_ entry: HistoryEntry) {
        session.selectHistoryEntry(entry)
        pullSessionChrome()
        showHistory = false
        selectedSegment = .create
    }

    var todayCreatedEntries: [HistoryEntry] {
        _ = historyRevision
        return session.todayCreatedEntries()
    }

    var editingSharedDetailEntry: HistoryEntry? {
        guard let editingSharedDetailEntryID else { return nil }
        return historyEntries.first(where: { $0.id == editingSharedDetailEntryID })
    }

    var canEditSharedDetailForSelection: Bool {
        guard let entry = editingSharedDetailEntry else { return false }
        return !entry.createdEventIdentifiers.isEmpty
    }

    func beginSharedDetailEdit(for entry: HistoryEntry) {
        sharedDetailEditOutcomeVisible = false
        sharedDetailResultOnToday = false
        if showHistory {
            showHistory = false
        }
        editingSharedDetailEntryID = entry.id
        sharedDetailDraft = entry.sharedDetail ?? ""
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
        sharedDetailDraft = ""
        sharedDetailEditOutcomeVisible = false
    }

    @discardableResult
    func commitSharedDetailEdit() -> SharedDetailUpdateOutcome {
        guard let entry = editingSharedDetailEntry else { return .unavailable }
        let outcome = updateSharedDetail(for: entry, detail: sharedDetailDraft)
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
    }

    @discardableResult
    func deleteSearchResult(_ event: CalendarEventInfo) -> Bool {
        let success = browse.deleteSearchResult(event)
        searchResults = browse.searchResults
        selectedSearchResult = browse.selectedSearchResult
        displayedEvents = browse.displayedEvents
        if success {
            session.discardRecordedContainingEvent(id: event.id)
            refreshHistoryProjection()
        }
        return success
    }

    func resetSearch() {
        browse.resetSearch()
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
}
