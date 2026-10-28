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
    private let defaults: UserDefaults
    private let outcomes: CreateSuccessOutcomes
    private let occurrenceStatuses: OccurrenceStatusStore

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
        occurrenceStatuses: OccurrenceStatusStore = OccurrenceStatusStore(),
        reviewIntervals: [Int]? = nil,
        customPresets: [CustomPreset]? = nil,
        selectedCalendarIdentifier: String = "",
        defaults: UserDefaults = .standard
    ) {
        self.calendar = calendar
        self.defaults = defaults
        self.outcomes = outcomes
        self.occurrenceStatuses = occurrenceStatuses
        self.reviewIntervals = reviewIntervals ?? Self.loadIntervals(from: defaults)
        self.customPresets = customPresets ?? Self.loadCustomPresets(from: defaults)
        self.selectedCalendarIdentifier = selectedCalendarIdentifier
        authorizationStatus = calendar.checkAuthorizationStatus()
        syncCalendarStateFromSeam()
        if authorizationStatus == .fullAccess,
           !self.selectedCalendarIdentifier.isEmpty,
           calendar.calendar(withIdentifier: self.selectedCalendarIdentifier) == nil {
            self.selectedCalendarIdentifier = ""
        }
        updateReviewDates()
    }

    func occurrenceStatus(for eventId: String) -> OccurrenceStatus {
        let key = statusKey(for: eventId)
        let direct = occurrenceStatuses.status(for: key)
        if direct != .unmarked { return direct }
        let legacy = occurrenceStatuses.status(for: HistorySeriesLookup.legacyKey(for: eventId))
        if legacy != .unmarked { return legacy }
        return occurrenceStatuses.status(for: eventId)
    }

    func setOccurrenceStatus(eventId: String, status: OccurrenceStatus) {
        guard isReviewSeriesEvent(eventId) else { return }
        occurrenceStatuses.setStatus(status, for: statusKey(for: eventId))
    }

    private func statusKeys(for entry: HistoryEntry, eventIds: [String] = []) -> [String] {
        let series = entry.reviewDates.indices.map {
            HistorySeriesLookup.seriesKey(entryID: entry.id, index: $0)
        }
        let legacy = (eventIds + entry.createdEventIdentifiers)
            .filter { !$0.isEmpty }
            .map { HistorySeriesLookup.legacyKey(for: $0) }
        return series + legacy
    }

    func statusKey(for eventId: String) -> String {
        if let event = calendar.event(withId: eventId) {
            return HistorySeriesLookup.stableKey(for: event, in: outcomes.recordedEntries())
        }
        for entry in outcomes.recordedEntries() where entry.type == .review {
            guard let index = entry.createdEventIdentifiers.firstIndex(of: eventId) else { continue }
            guard index < entry.reviewDates.count else { continue }
            return HistorySeriesLookup.seriesKey(entryID: entry.id, index: index)
        }
        return HistorySeriesLookup.legacyKey(for: eventId)
    }

    func canMarkOccurrence(eventId: String) -> Bool {
        isReviewSeriesEvent(eventId)
    }

    func occurrenceMaterials(weekStart: Date, weekEnd: Date) -> [OccurrenceReviewMaterial] {
        let marked = occurrenceStatuses.markedEntries()
        guard !marked.isEmpty else { return [] }
        let start = Calendar.current.startOfDay(for: weekStart)
        let end = Calendar.current.startOfDay(for: weekEnd)
        var materials: [OccurrenceReviewMaterial] = []
        for entry in outcomes.recordedEntries() where entry.type == .review {
            for (index, day) in entry.reviewDates.enumerated() {
                let key = HistorySeriesLookup.seriesKey(entryID: entry.id, index: index)
                guard let status = marked[key] else { continue }
                let target = Calendar.current.startOfDay(for: day)
                guard target >= start && target <= end else { continue }
                guard let event = resolvedEvent(for: entry, index: index) else { continue }
                materials.append(
                    OccurrenceReviewMaterial(
                        eventId: event.id,
                        title: entry.title,
                        occurrenceDate: event.start,
                        status: status
                    )
                )
            }
        }
        return materials.sorted { $0.occurrenceDate > $1.occurrenceDate }
    }

    private func resolvedEvent(for entry: HistoryEntry, index: Int) -> CalendarEventInfo? {
        guard index < entry.reviewDates.count else { return nil }
        let day = entry.reviewDates[index]
        if index < entry.createdEventIdentifiers.count,
           let exact = calendar.event(withId: entry.createdEventIdentifiers[index]) {
            return exact
        }
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        return calendar.fetchEvents(from: start, to: end).first { $0.title == entry.title }
    }

    private func isReviewSeriesEvent(_ eventId: String) -> Bool {
        let history = outcomes.recordedEntries()
        if let entry = HistorySeriesLookup.entry(containingEventId: eventId, in: history) {
            return entry.type == .review
        }
        guard let event = calendar.event(withId: eventId) else { return false }
        return HistorySeriesLookup.entry(matching: event, in: history) != nil
    }

    private func reviewSeriesEventIds() -> Set<String> {
        Set(
            outcomes.recordedEntries()
                .filter { $0.type == .review }
                .flatMap(\.createdEventIdentifiers)
        )
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
        PersistentArray<Int>(key: "reviewIntervalsData", defaults: defaults).save(reviewIntervals)
    }

    func persistCustomPresets() {
        PersistentArray<CustomPreset>(key: "customPresetsData", defaults: defaults).save(customPresets)
    }

    func persistSelectedCalendar() {
        defaults.set(selectedCalendarIdentifier, forKey: "selectedCalendarIdentifier")
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
        let store = PersistentArray<CustomPreset>(key: "customPresetsData", defaults: defaults)
        let existing = store.load()
        guard !existing.contains(where: { $0.name == trimmed }),
              !customPresets.contains(where: { $0.name == trimmed }) else {
            customPresets = existing
            return
        }
        customPresets = existing + [CustomPreset(name: trimmed, intervals: reviewIntervals)]
        store.save(customPresets)
    }

    func applyCustomPreset(_ preset: CustomPreset) {
        reviewIntervals = preset.intervals
        persistIntervals()
        updateReviewDates()
    }

    func deleteCustomPreset(id: UUID) {
        let store = PersistentArray<CustomPreset>(key: "customPresetsData", defaults: defaults)
        customPresets = store.load().filter { $0.id != id }
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
    func discardRecordedEntry(id: UUID) {
        if let entry = outcomes.recordedEntries().first(where: { $0.id == id }) {
            occurrenceStatuses.clear(ids: statusKeys(for: entry))
        }
        outcomes.discardRecorded(id: id)
    }

    func discardRecordedContainingEvent(id: String) -> UUID? {
        let entry = outcomes.recordedEntries().first(where: {
            $0.createdEventIdentifiers.contains(id)
        })
        let result = outcomes.discardRecordedContainingEvent(id: id)
        if let entry, result != nil {
            occurrenceStatuses.clear(ids: statusKeys(for: entry, eventIds: [id]))
        } else {
            occurrenceStatuses.clear(ids: [statusKey(for: id)])
        }
        return result
    }

    @discardableResult
    func removeEventsFromRecorded(
        ids: [String],
        reason: RecordedPruneReason
    ) -> RemoveEventsFromRecordedOutcome {
        let outcome = outcomes.removeEventsFromRecorded(ids: ids, reason: reason)
        switch outcome {
        case .updated, .discarded:
            occurrenceStatuses.clear(ids: ids.map { statusKey(for: $0) })
        case .noMatch, .refusedNoAuthority:
            break
        }
        return outcome
    }

    @discardableResult
    func reconcileRecordedWithCalendar() -> ReconcileOutcome {
        guard CalendarLookupAuthority.verified(authorizationStatus) != nil else {
            return .skippedNoAccess
        }
        migrateLegacyStatusKeys()
        var unmatched = 0
        for entry in outcomes.recordedEntries() {
            let identifiers = entry.createdEventIdentifiers
            guard !identifiers.isEmpty else { continue }
            unmatched += identifiers.filter { calendar.event(withId: $0) == nil }.count
        }
        return unmatched > 0 ? .unmatched(count: unmatched) : .unchanged
    }

    private func migrateLegacyStatusKeys() {
        let marked = occurrenceStatuses.markedEntries()
        let legacy = marked.filter { !$0.key.hasPrefix("series:") }
        guard !legacy.isEmpty else { return }
        var relocated: [String: OccurrenceStatus] = [:]
        var consumed: [String] = []
        for (key, status) in legacy {
            let eventId = key.hasPrefix("event:") ? String(key.dropFirst("event:".count)) : key
            guard let event = calendar.event(withId: eventId) else { continue }
            let stable = HistorySeriesLookup.stableKey(for: event, in: outcomes.recordedEntries())
            guard stable.hasPrefix("series:") else { continue }
            relocated[stable] = status
            consumed.append(key)
        }
        guard !consumed.isEmpty else { return }
        for (key, status) in relocated {
            occurrenceStatuses.setStatus(status, for: key)
        }
        occurrenceStatuses.clear(ids: consumed)
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

    @discardableResult
    func updateSeriesTitle(for entry: HistoryEntry, title: String) -> SharedDetailUpdateOutcome {
        resultMessage = nil
        resultType = nil

        let identifiers = entry.createdEventIdentifiers
        guard !identifiers.isEmpty else {
            resultMessage = NSLocalizedString("series_title_unavailable", comment: "")
            resultType = .warning
            return .unavailable
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let counts = CalendarWriteOrchestrator.rewriteSeriesTitle(
            identifiers: identifiers,
            title: trimmedTitle,
            updateEventTitle: { [calendar] id, newTitle in calendar.updateEventTitle(id: id, title: newTitle) }
        )
        let updated = counts.updated
        let missing = counts.missing

        if updated > 0 {
            outcomes.updateTitle(id: entry.id, title: trimmedTitle)
        }

        if missing == 0 {
            resultMessage = String(
                format: NSLocalizedString("series_title_success", comment: ""),
                "\(updated)"
            )
            resultType = .success
        } else if updated > 0 {
            resultMessage = String(
                format: NSLocalizedString("series_title_partial", comment: ""),
                "\(updated)",
                "\(missing)"
            )
            resultType = .warning
        } else {
            resultMessage = String(
                format: NSLocalizedString("series_title_all_missing", comment: ""),
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
        let frozenBaseDate = baseDate
        let frozenMode = scheduleMode
        let frozenIntervals = reviewIntervals

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
            switch frozenMode {
            case .review:
                createResult = try await calendar.createReviewEvents(
                    title: trimmedTitle,
                    baseDate: frozenBaseDate,
                    intervals: frozenIntervals,
                    calendarId: calendarId,
                    detail: detailForWrite
                )
            case .single:
                createResult = try await calendar.createSingleEvent(
                    title: trimmedTitle,
                    date: frozenBaseDate,
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
                let written = Self.datesWrittenDespiteDuplicates(createResult)
                if !written.isEmpty {
                    onCreateSuccess(
                        trimmed: trimmedTitle,
                        created: written,
                        sharedDetail: detailForWrite,
                        baseDate: frozenBaseDate,
                        mode: frozenMode
                    )
                }
            } else {
                resultMessage = String(
                    format: NSLocalizedString("write_success_count", comment: ""),
                    createResult.created.count
                )
                resultType = .success
                onCreateSuccess(
                    trimmed: trimmedTitle,
                    created: createResult.created,
                    sharedDetail: detailForWrite,
                    baseDate: frozenBaseDate,
                    mode: frozenMode
                )
            }
        } catch {
            resultMessage = error.localizedDescription
            resultType = .error
        }
    }

    func undo() async {
        let undo = await calendar.undoLastCreation()
        let recordedID = lastRecordedHistoryEntryID

        if undo.success {
            resultMessage = String(
                format: NSLocalizedString("undo_success_count", comment: ""),
                undo.deletedCount
            )
            resultType = .success
        } else {
            resultMessage = String(format: NSLocalizedString("undo_partial", comment: ""), "\(undo.alreadyDeletedCount)")
            resultType = .warning
        }

        if let recordedID, undo.deletedCount > 0 || undo.success {
            if let entry = outcomes.recordedEntries().first(where: { $0.id == recordedID }) {
                occurrenceStatuses.clear(ids: statusKeys(for: entry))
            }
            outcomes.discardRecorded(id: recordedID)
            lastRecordedHistoryEntryID = nil
            canUndo = false
            canRecreate = false
        }
    }

    private func onCreateSuccess(
        trimmed: String,
        created: [Date],
        sharedDetail: String?,
        baseDate writtenBaseDate: Date,
        mode writtenMode: ScheduleMode
    ) {
        shouldPlayHaptic = true
        lastCreatedTitle = trimmed
        lastCreatedBaseDate = writtenBaseDate
        canRecreate = true
        canUndo = true
        let entry = HistoryEntry(
            title: trimmed,
            baseDate: writtenBaseDate,
            reviewDates: created,
            creationDate: Date(),
            type: writtenMode == .single ? .single : .review,
            createdEventIdentifiers: Self.effectiveIdentifiers(
                created: created,
                calendar: calendar
            ),
            sharedDetail: sharedDetail
        )
        outcomes.record(entry)
        lastRecordedHistoryEntryID = entry.id
        title = ""
        detail = ""
        updateReviewDates()
    }

    private static func effectiveIdentifiers(
        created: [Date],
        calendar: CalendarService
    ) -> [String] {
        let pairs = calendar.lastCreatedPairs
        guard !pairs.isEmpty else { return calendar.lastCreatedEventIdentifiers }
        return created.compactMap { day in
            pairs.first { Calendar.current.isDate($0.date, inSameDayAs: day) }?.id
        }
    }

    private static func datesWrittenDespiteDuplicates(_ result: CreateEventsResult) -> [Date] {
        result.created.filter { day in
            !result.duplicates.contains { Calendar.current.isDate($0, inSameDayAs: day) }
        }
    }

    private static func optionalDetail(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loadIntervals(from defaults: UserDefaults) -> [Int] {
        let intervals = PersistentArray<Int>(key: "reviewIntervalsData", defaults: defaults)
            .load()
        guard IntervalRules.validate(intervals) else {
            return IntervalRules.defaultIntervals
        }
        return intervals
    }

    private static func loadCustomPresets(from defaults: UserDefaults) -> [CustomPreset] {
        PersistentArray<CustomPreset>(key: "customPresetsData", defaults: defaults).load()
    }
}
