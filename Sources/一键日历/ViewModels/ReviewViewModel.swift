import Foundation
import SwiftUI
import AppKit
import EventKit
import Combine

@MainActor
class ReviewViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var baseDate: Date = Date()
    @Published var reviewDates: [Date] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var resultMessage: String?
    @Published var resultType: ResultType?
    @Published var canUndo: Bool = false
    @Published var canRecreate: Bool = false
    @Published var showHistory: Bool = false
    @Published var showFirstRunGuide: Bool = false
    @Published var showHelpGuide: Bool = false
    @Published var showSearch: Bool = false
    @Published var searchText: String = ""
    @Published var searchResults: [EKEvent] = []
    @Published var selectedSearchResult: EKEvent?
    @Published var displayedEvents: [EKEvent] = []
    @Published var historySearchText: String = ""
    @Published var currentTheme: Theme = {
        let rawValue = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: rawValue) ?? .light
    }()
    
    /// 桥接 CalendarManager 的日历列表（按 source 分组，本地排最后）
    @Published var availableCalendars: [EKCalendar] = []
    @Published var hasCloudCalendar: Bool = false
    
    /// 最近一次创建的标题和日期，用于「再建一个」
    private var lastCreatedTitle: String?
    private var lastCreatedBaseDate: Date?
    
    /// JSON 编码的复习间隔数组，默认 [3, 7, 30]
    @AppStorage("reviewIntervalsData") private var reviewIntervalsData: String = "[3,7,30]"
    /// JSON 编码的历史记录数组
    @AppStorage("historyEntriesData") private var historyEntriesData: String = ""
    /// 用户选中的目标日历 identifier（空字符串 = 跟随系统默认）
    @AppStorage("selectedCalendarIdentifier") var selectedCalendarIdentifier: String = ""
    /// 是否已经展示过首次启动引导
    @AppStorage("hasShownFirstRunGuide") private var hasShownFirstRunGuide: Bool = false
    
    var reviewIntervals: [Int] {
        get {
            guard let data = reviewIntervalsData.data(using: .utf8),
                  let intervals = try? JSONDecoder().decode([Int].self, from: data) else {
                return [3, 7, 30]
            }
            return intervals
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                reviewIntervalsData = string
            }
        }
    }
    
    var historyEntries: [HistoryEntry] {
        get {
            guard let data = historyEntriesData.data(using: .utf8),
                  let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                historyEntriesData = string
            }
        }
    }
    
    private let calendarManager = CalendarManager.shared
    private var notificationToken: Any?
    private var activeToken: Any?
    private var resultDismissTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    /// 当前选中的日历（identifier 失效时返回 nil，会回退到系统默认）
    var selectedCalendar: EKCalendar? {
        guard !selectedCalendarIdentifier.isEmpty else { return nil }
        return calendarManager.calendar(withIdentifier: selectedCalendarIdentifier)
    }
    
    /// 当前选中的是否是本地日历（用于 UI 警告）
    var isSelectedCalendarLocal: Bool {
        selectedCalendar?.source.sourceType == .local
    }
    
    /// 选中的日历显示名（identifier 为空时显示"系统默认"）
    var selectedCalendarDisplayName: String {
        if let cal = selectedCalendar { return "\(cal.source.title) → \(cal.title)" }
        return NSLocalizedString("calendar_default_label", comment: "")
    }
    
    enum ResultType {
        case success
        case warning
        case error
    }
    
    init() {
        authorizationStatus = calendarManager.checkAuthorizationStatus()
        updateReviewDates()
        
        // 桥接 CalendarManager 的日历列表
        availableCalendars = calendarManager.availableCalendars
        hasCloudCalendar = calendarManager.hasCloudCalendar
        calendarManager.$availableCalendars
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableCalendars)
        calendarManager.$hasCloudCalendar
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasCloudCalendar)
        
        // 若用户之前选中的日历已失效（如被删除/账户注销），自动清空
        if !selectedCalendarIdentifier.isEmpty,
           calendarManager.calendar(withIdentifier: selectedCalendarIdentifier) == nil {
            selectedCalendarIdentifier = ""
        }
        
        notificationToken = NotificationCenter.default.addObserver(
            forName: .createReviewSchedule,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.createReviewSchedule()
            }
        }
        
        activeToken = NotificationCenter.default.addObserver(
            forName: .appDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // 用户在系统设置里改了账户后，回来重新扫描
                self.calendarManager.refreshAvailableCalendars()
                if self.authorizationStatus == .fullAccess {
                    self.loadDisplayedDayEvents()
                }
            }
        }
        
        // 启动时请求权限并加载今天日程
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.authorizationStatus == .notDetermined {
                let granted = await self.calendarManager.requestAccess()
                self.authorizationStatus = self.calendarManager.checkAuthorizationStatus()
                if granted {
                    self.loadDisplayedDayEvents()
                }
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
    
    func updateReviewDates() {
        reviewDates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: reviewIntervals)
    }
    
    /// 主流程：创建复习提醒日程
    /// 1. 校验标题（非空、≤100字符）
    /// 2. 检查/请求日历权限
    /// 3. 调用 CalendarManager 创建事件
    /// 4. 处理结果并更新 UI
    func createReviewSchedule() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        
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
        
        // Check and request permission if needed
        if authorizationStatus == .notDetermined {
            let granted = await calendarManager.requestAccess()
            authorizationStatus = calendarManager.checkAuthorizationStatus()
            if !granted {
                resultMessage = NSLocalizedString("permission_required", comment: "")
                resultType = .error
                return
            }
        } else if authorizationStatus == .denied {
            resultMessage = NSLocalizedString("permission_denied", comment: "")
            resultType = .error
            return
        }
        
        do {
            let targetCalendar = selectedCalendar
            // 选中失效的 identifier 时回退到系统默认，并提示
            if !selectedCalendarIdentifier.isEmpty && targetCalendar == nil {
                resultMessage = NSLocalizedString("calendar_selection_invalid", comment: "")
                resultType = .warning
                selectedCalendarIdentifier = ""
                scheduleResultDismissal()
                return
            }
            let (created, duplicates, failed) = try await calendarManager.createReviewEvents(
                title: trimmedTitle,
                baseDate: baseDate,
                intervals: reviewIntervals,
                calendar: targetCalendar
            )
            
            if !failed.isEmpty {
                let failedDates = failed.map { $0.0.formattedChinese() }.joined(separator: "、")
                resultMessage = String(format: NSLocalizedString("error_message", comment: ""), failedDates)
                resultType = .error
            } else if !duplicates.isEmpty {
                let dupDates = duplicates.map { $0.formattedChinese() }.joined(separator: "、")
                resultMessage = String(format: NSLocalizedString("warning_message", comment: ""), dupDates)
                resultType = .warning
            } else {
                let createdDates = created.map { $0.formattedChinese() }.joined(separator: "、")
                resultMessage = String(format: NSLocalizedString("success_message", comment: ""), createdDates)
                resultType = .success
                
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                
                // Save for recreate
                lastCreatedTitle = trimmedTitle
                lastCreatedBaseDate = baseDate
                canRecreate = true
                
                // Add to history
                addHistoryEntry(title: trimmedTitle, baseDate: baseDate, reviewDates: created)
                
                // Enable undo
                canUndo = true
                
                // Clear inputs after success
                title = ""
                baseDate = Date()
                updateReviewDates()
                
                // 刷新当前查看的日程
                loadDisplayedDayEvents()
            }
        } catch {
            resultMessage = error.localizedDescription
            resultType = .error
        }
        
        scheduleResultDismissal()
    }
    
    /// 撤销最近一次创建的复习日程
    func undoReviewSchedule() async {
        let (success, deletedCount, alreadyDeletedCount) = await calendarManager.undoLastCreation()
        let title = lastCreatedTitle ?? ""
        
        if success {
            if title.isEmpty {
                resultMessage = String(format: NSLocalizedString("undo_success", comment: ""), "\(deletedCount)")
            } else {
                resultMessage = String(format: NSLocalizedString("undo_success_with_title", comment: ""), title, "\(deletedCount)")
            }
            resultType = .success
        } else {
            resultMessage = String(format: NSLocalizedString("undo_partial", comment: ""), "\(alreadyDeletedCount)")
            resultType = .warning
        }
        
        canUndo = false
        canRecreate = false
        loadDisplayedDayEvents()
        scheduleResultDismissal()
    }
    
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Day Events
    
    enum DayType: String, CaseIterable, Identifiable {
        case yesterday
        case today
        case tomorrow
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .yesterday: return NSLocalizedString("yesterday_button", comment: "")
            case .today: return NSLocalizedString("today_button", comment: "")
            case .tomorrow: return NSLocalizedString("tomorrow_button", comment: "")
            }
        }
        
        var dayOffset: Int {
            switch self {
            case .yesterday: return -1
            case .today: return 0
            case .tomorrow: return 1
            }
        }
        
        var sectionTitle: String {
            switch self {
            case .yesterday: return NSLocalizedString("yesterday_events", comment: "")
            case .today: return NSLocalizedString("today_events", comment: "")
            case .tomorrow: return NSLocalizedString("tomorrow_events", comment: "")
            }
        }
        
        var emptyHint: String {
            switch self {
            case .yesterday: return NSLocalizedString("yesterday_no_events", comment: "")
            case .today: return NSLocalizedString("today_no_events", comment: "")
            case .tomorrow: return NSLocalizedString("tomorrow_no_events", comment: "")
            }
        }
    }
    
    /// 当前查看的日期类型（默认今天，不持久化）
    @Published var selectedDayType: DayType = .today
    
    /// 当前查看的日期（由 selectedDayType 计算）
    var displayedDate: Date {
        date(for: selectedDayType)
    }
    
    func date(for dayType: DayType) -> Date {
        Calendar.current.date(byAdding: .day, value: dayType.dayOffset, to: Date()) ?? Date()
    }
    
    func loadDisplayedDayEvents() {
        displayedEvents = calendarManager.fetchEvents(on: displayedDate)
    }
    
    /// 用户切换日期按钮时调用
    func selectDayType(_ dayType: DayType) {
        selectedDayType = dayType
        loadDisplayedDayEvents()
    }
    
    // MARK: - Result Auto-Dismiss
    
    /// 成功/警告提示 4 秒后自动消失，错误提示保留
    private func scheduleResultDismissal() {
        resultDismissTask?.cancel()
        guard resultType == .success || resultType == .warning else { return }
        resultDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.resultMessage = nil
                self?.resultType = nil
            }
        }
    }
    
    // MARK: - Recreate
    
    func recreateLastSchedule() {
        guard let title = lastCreatedTitle, let baseDate = lastCreatedBaseDate else { return }
        self.title = title
        self.baseDate = baseDate
        updateReviewDates()
        canRecreate = false
    }
    
    // MARK: - History
    
    private func addHistoryEntry(title: String, baseDate: Date, reviewDates: [Date]) {
        var entries = historyEntries
        let newEntry = HistoryEntry(title: title, baseDate: baseDate, reviewDates: reviewDates, creationDate: Date())
        entries.insert(newEntry, at: 0)
        
        // Limit to 20 entries
        if entries.count > 20 {
            entries = Array(entries.prefix(20))
        }
        
        historyEntries = entries
    }
    
    func selectHistoryEntry(_ entry: HistoryEntry) {
        title = entry.title
        baseDate = entry.baseDate
        updateReviewDates()
        showHistory = false
    }
    
    func clearHistory() {
        historyEntries = []
    }
    
    func deleteHistoryEntry(at offsets: IndexSet) {
        var entries = historyEntries
        entries.remove(atOffsets: offsets)
        historyEntries = entries
    }
    
    var filteredHistoryEntries: [HistoryEntry] {
        guard !historySearchText.isEmpty else { return historyEntries }
        return historyEntries.filter { $0.title.localizedCaseInsensitiveContains(historySearchText) }
    }
    
    // MARK: - Interval Presets
    
    func applyPreset(_ preset: IntervalPreset) {
        reviewIntervals = preset.intervals
        updateReviewDates()
    }
    
    // MARK: - Interval Settings
    
    func resetIntervalsToDefault() {
        reviewIntervals = [3, 7, 30]
        updateReviewDates()
    }
    
    func validateIntervals(_ intervals: [Int]) -> Bool {
        return intervals.allSatisfy { $0 >= 1 && $0 <= 365 }
    }
    
    // MARK: - Window Settings
    
    /// 窗口是否置顶（浮动层级）。默认 true，老用户行为不变
    @Published var windowFloating: Bool = UserDefaults.standard.object(forKey: "windowFloating") as? Bool ?? true {
        didSet { UserDefaults.standard.set(windowFloating, forKey: "windowFloating") }
    }
    
    /// 把当前 windowFloating 偏好应用到所有窗口
    func applyWindowLevel() {
        let level: NSWindow.Level = windowFloating ? .floating : .normal
        NSApp.windows.forEach { $0.level = level }
    }
    
    // MARK: - First Run Guide
    
    /// 启动 3 秒后若没有云日历且未引导过，自动弹出引导
    func scheduleFirstRunGuideIfNeeded() {
        guard !hasShownFirstRunGuide else { return }
        guard authorizationStatus == .fullAccess else { return }
        guard !hasCloudCalendar else { return }
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self = self, !Task.isCancelled else { return }
            // 再次校验（3s 内用户可能已经手动加账户）
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
    
    // MARK: - Theme

    func setTheme(_ theme: Theme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
        UserDefaults.standard.set(theme.rawValue, forKey: "themeName")
    }

    // MARK: - Search

    /// 在未来 90 天内搜索标题包含关键词的事件
    func performSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        searchResults = calendarManager.searchEvents(query: trimmed, daysAhead: 90)
    }

    /// 关闭搜索 sheet 时重置状态
    func resetSearch() {
        searchText = ""
        searchResults = []
        selectedSearchResult = nil
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
