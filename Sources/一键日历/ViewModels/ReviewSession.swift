import Foundation

@MainActor
final class ReviewSession {
    enum ResultType {
        case success
        case warning
        case error
    }

    enum ScheduleMode: String, CaseIterable, Identifiable {
        case review
        case single

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .review: return NSLocalizedString("schedule_mode_review", comment: "")
            case .single: return NSLocalizedString("schedule_mode_single", comment: "")
            }
        }
    }

    private let calendar: CalendarService
    private let outcomes: CreateSuccessOutcomes

    var title: String = ""
    var detail: String = ""
    var baseDate: Date = Date()
    var reviewDates: [Date] = []
    var scheduleMode: ScheduleMode = .review
    var reviewIntervals: [Int]
    var customPresets: [CustomPreset]
    var selectedCalendarIdentifier: String
    var authorizationStatus: CalendarAccessStatus = .notDetermined
    var availableCalendars: [CalendarInfo] = []
    var hasCloudCalendar: Bool = false
    var isLoading: Bool = false
    var resultMessage: String?
    var resultType: ResultType?
    var canUndo: Bool = false
    var canRecreate: Bool = false

    private var lastCreatedTitle: String?
    private var lastCreatedBaseDate: Date?
    private var lastRecordedHistoryEntryID: UUID?

    private(set) var shouldPlayHaptic: Bool = false

    var selectedCalendar: CalendarInfo? {
        guard !selectedCalendarIdentifier.isEmpty else { return nil }
        return calendar.calendar(withIdentifier: selectedCalendarIdentifier)
    }

    var isSelectedCalendarLocal: Bool {
        selectedCalendar?.sourceKind == .local
    }

    var selectedCalendarDisplayName: String {
        if let cal = selectedCalendar { return cal.displayName }
        return NSLocalizedString("calendar_default_label", comment: "")
    }

    init(
        calendar: CalendarService,
        outcomes: CreateSuccessOutcomes,
        reviewIntervals: [Int]? = nil,
        customPresets: [CustomPreset]? = nil,
        selectedCalendarIdentifier: String = ""
    ) {
        self.calendar = calendar
        self.outcomes = outcomes
        self.reviewIntervals = reviewIntervals ?? Self.loadIntervals()
        self.customPresets = customPresets ?? Self.loadCustomPresets()
        self.selectedCalendarIdentifier = selectedCalendarIdentifier
        authorizationStatus = calendar.checkAuthorizationStatus()
        syncCalendarStateFromSeam()
        if !self.selectedCalendarIdentifier.isEmpty,
           calendar.calendar(withIdentifier: self.selectedCalendarIdentifier) == nil {
            self.selectedCalendarIdentifier = ""
        }
        updateReviewDates()
    }

    func syncCalendarStateFromSeam() {
        availableCalendars = calendar.availableCalendars
        hasCloudCalendar = calendar.hasCloudCalendar
        authorizationStatus = calendar.authorizationStatus
    }

    func refreshCalendars() {
        calendar.refreshAvailableCalendars()
        syncCalendarStateFromSeam()
    }

    @discardableResult
    func requestAccessIfNeeded() async -> Bool {
        if authorizationStatus == .notDetermined {
            let granted = await calendar.requestAccess()
            authorizationStatus = calendar.checkAuthorizationStatus()
            syncCalendarStateFromSeam()
            return granted
        }
        syncCalendarStateFromSeam()
        return authorizationStatus == .fullAccess
    }

    func updateReviewDates() {
        switch scheduleMode {
        case .review:
            reviewDates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: reviewIntervals)
        case .single:
            reviewDates = [baseDate]
        }
    }

    func persistIntervals() {
        if let data = try? JSONEncoder().encode(reviewIntervals),
           let string = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(string, forKey: "reviewIntervalsData")
        }
    }

    func persistCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets),
           let string = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(string, forKey: "customPresetsData")
        }
    }

    func persistSelectedCalendar() {
        UserDefaults.standard.set(selectedCalendarIdentifier, forKey: "selectedCalendarIdentifier")
    }

    func applyPreset(_ preset: IntervalPreset) {
        reviewIntervals = preset.intervals
        persistIntervals()
        updateReviewDates()
    }

    func resetIntervalsToDefault() {
        reviewIntervals = IntervalRules.defaultIntervals
        persistIntervals()
        updateReviewDates()
    }

    @discardableResult
    func commitIntervalDraft(_ draft: [String]) -> Result<[Int], IntervalDraftFailure> {
        switch IntervalRules.parseDraft(draft) {
        case .success(let intervals):
            reviewIntervals = intervals
            persistIntervals()
            updateReviewDates()
            return .success(intervals)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    func saveCustomPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !customPresets.contains(where: { $0.name == trimmed }) else { return }
        customPresets.append(CustomPreset(name: trimmed, intervals: reviewIntervals))
        persistCustomPresets()
    }

    func applyCustomPreset(_ preset: CustomPreset) {
        reviewIntervals = preset.intervals
        persistIntervals()
        updateReviewDates()
    }

    func deleteCustomPreset(id: UUID) {
        customPresets = customPresets.filter { $0.id != id }
        persistCustomPresets()
    }

    func hasDuplicatePresetName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return customPresets.contains(where: { $0.name == trimmed })
    }

    func selectHistoryEntry(_ entry: HistoryEntry) {
        title = entry.title
        baseDate = entry.baseDate
        updateReviewDates()
    }

    func recreateLastSchedule() {
        guard let title = lastCreatedTitle, let baseDate = lastCreatedBaseDate else { return }
        self.title = title
        self.baseDate = baseDate
        updateReviewDates()
        canRecreate = false
    }

    func todayCreatedEntries(now: Date = Date(), calendar: Calendar = .current) -> [HistoryEntry] {
        outcomes.todayCreatedEntries(now: now, calendar: calendar)
    }

    @discardableResult
    func discardRecordedContainingEvent(id: String) -> UUID? {
        outcomes.discardRecordedContainingEvent(id: id)
    }

    @discardableResult
    func removeEventsFromRecorded(ids: [String]) -> RemoveEventsFromRecordedOutcome {
        outcomes.removeEventsFromRecorded(ids: ids)
    }

    @discardableResult
    func updateSharedDetail(for entry: HistoryEntry, detail: String) -> SharedDetailUpdateOutcome {
        resultMessage = nil
        resultType = nil

        let identifiers = entry.createdEventIdentifiers
        guard !identifiers.isEmpty else {
            resultMessage = NSLocalizedString("shared_detail_unavailable", comment: "")
            resultType = .warning
            return .unavailable
        }

        let detailForWrite = Self.optionalDetail(from: detail)
        let counts = CalendarWriteOrchestrator.rewriteSharedDetail(
            identifiers: identifiers,
            detail: detailForWrite,
            eventNotes: { [calendar] id in calendar.eventNotes(id: id) },
            updateEventNotes: { [calendar] id, notes in calendar.updateEventNotes(id: id, notes: notes) }
        )
        let updated = counts.updated
        let missing = counts.missing

        if updated > 0 {
            outcomes.updateSharedDetail(id: entry.id, sharedDetail: detailForWrite)
        }

        if missing == 0 {
            resultMessage = String(
                format: NSLocalizedString("shared_detail_success", comment: ""),
                "\(updated)"
            )
            resultType = .success
        } else if updated > 0 {
            resultMessage = String(
                format: NSLocalizedString("shared_detail_partial", comment: ""),
                "\(updated)",
                "\(missing)"
            )
            resultType = .warning
        } else {
            resultMessage = String(
                format: NSLocalizedString("shared_detail_all_missing", comment: ""),
                "\(missing)"
            )
            resultType = .warning
        }

        return .updated(updated: updated, missing: missing)
    }

    func consumeHapticFlag() -> Bool {
        let flag = shouldPlayHaptic
        shouldPlayHaptic = false
        return flag
    }

    func create() async {
        shouldPlayHaptic = false
        resultMessage = nil
        resultType = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let detailForWrite = Self.optionalDetail(from: detail)

        guard !trimmedTitle.isEmpty else {
            resultMessage = NSLocalizedString("empty_title_error", comment: "")
            resultType = .error
            return
        }

        guard trimmedTitle.count <= 100 else {
            resultMessage = NSLocalizedString("title_too_long_error", comment: "")
            resultType = .error
            return
        }

        isLoading = true
        defer { isLoading = false }

        if authorizationStatus == .notDetermined {
            let granted = await calendar.requestAccess()
            authorizationStatus = calendar.checkAuthorizationStatus()
            syncCalendarStateFromSeam()
            if !granted {
                resultMessage = NSLocalizedString("permission_required", comment: "")
                resultType = .error
                return
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            resultMessage = NSLocalizedString("permission_denied", comment: "")
            resultType = .error
            return
        }

        do {
            let targetCalendar = selectedCalendar
            if !selectedCalendarIdentifier.isEmpty && targetCalendar == nil {
                resultMessage = NSLocalizedString("calendar_selection_invalid", comment: "")
                resultType = .warning
                selectedCalendarIdentifier = ""
                persistSelectedCalendar()
                return
            }

            let calendarId = targetCalendar?.identifier
            let createResult: CreateEventsResult
            switch scheduleMode {
            case .review:
                createResult = try await calendar.createReviewEvents(
                    title: trimmedTitle,
                    baseDate: baseDate,
                    intervals: reviewIntervals,
                    calendarId: calendarId,
                    detail: detailForWrite
                )
            case .single:
                createResult = try await calendar.createSingleEvent(
                    title: trimmedTitle,
                    date: baseDate,
                    calendarId: calendarId,
                    detail: detailForWrite
                )
            }

            if !createResult.failed.isEmpty {
                let failedDates = createResult.failed.map { $0.date.formattedChinese() }.joined(separator: "、")
                resultMessage = String(format: NSLocalizedString("error_message", comment: ""), failedDates)
                resultType = .error
            } else if !createResult.duplicates.isEmpty {
                let dupDates = createResult.duplicates.map { $0.formattedChinese() }.joined(separator: "、")
                resultMessage = String(format: NSLocalizedString("warning_message", comment: ""), dupDates)
                resultType = .warning
            } else {
                if scheduleMode == .single {
                    let dateString = baseDate.formattedChinese()
                    resultMessage = String(format: NSLocalizedString("single_success_message", comment: ""), dateString)
                } else {
                    let createdDates = createResult.created.map { $0.formattedChinese() }.joined(separator: "、")
                    resultMessage = String(format: NSLocalizedString("success_message", comment: ""), createdDates)
                }
                resultType = .success
                onCreateSuccess(
                    trimmed: trimmedTitle,
                    created: createResult.created,
                    sharedDetail: detailForWrite
                )
            }
        } catch {
            resultMessage = error.localizedDescription
            resultType = .error
        }
    }

    func undo() async {
        let undo = await calendar.undoLastCreation()
        let undoneTitle = lastCreatedTitle ?? ""
        let recordedID = lastRecordedHistoryEntryID

        if undo.success {
            if undoneTitle.isEmpty {
                resultMessage = String(format: NSLocalizedString("undo_success", comment: ""), "\(undo.deletedCount)")
            } else {
                resultMessage = String(
                    format: NSLocalizedString("undo_success_with_title", comment: ""),
                    undoneTitle,
                    "\(undo.deletedCount)"
                )
            }
            resultType = .success
        } else {
            resultMessage = String(format: NSLocalizedString("undo_partial", comment: ""), "\(undo.alreadyDeletedCount)")
            resultType = .warning
        }

        if let recordedID {
            outcomes.discardRecorded(id: recordedID)
        }
        lastRecordedHistoryEntryID = nil
        canUndo = false
        canRecreate = false
    }

    private func onCreateSuccess(trimmed: String, created: [Date], sharedDetail: String?) {
        shouldPlayHaptic = true
        lastCreatedTitle = trimmed
        lastCreatedBaseDate = baseDate
        canRecreate = true
        canUndo = true
        let entry = HistoryEntry(
            title: trimmed,
            baseDate: baseDate,
            reviewDates: created,
            creationDate: Date(),
            type: scheduleMode == .single ? .single : .review,
            createdEventIdentifiers: calendar.lastCreatedEventIdentifiers,
            sharedDetail: sharedDetail
        )
        outcomes.record(entry)
        lastRecordedHistoryEntryID = entry.id
        title = ""
        detail = ""
        baseDate = Date()
        updateReviewDates()
    }

    private static func optionalDetail(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loadIntervals() -> [Int] {
        let raw = UserDefaults.standard.string(forKey: "reviewIntervalsData") ?? "[3,7,30]"
        guard let data = raw.data(using: .utf8),
              let intervals = try? JSONDecoder().decode([Int].self, from: data),
              IntervalRules.validate(intervals) else {
            return IntervalRules.defaultIntervals
        }
        return intervals
    }

    private static func loadCustomPresets() -> [CustomPreset] {
        let raw = UserDefaults.standard.string(forKey: "customPresetsData") ?? "[]"
        guard let data = raw.data(using: .utf8),
              let presets = try? JSONDecoder().decode([CustomPreset].self, from: data) else {
            return []
        }
        return presets
    }
}
