import Foundation
import SwiftUI
import AppKit
import EventKit

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
    @Published var todayEvents: [EKEvent] = []
    @Published var historySearchText: String = ""
    @Published var currentTheme: Theme = {
        let rawValue = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: rawValue) ?? .light
    }()
    
    /// 最近一次创建的标题和日期，用于「再建一个」
    private var lastCreatedTitle: String?
    private var lastCreatedBaseDate: Date?
    
    /// JSON 编码的复习间隔数组，默认 [3, 7, 30]
    @AppStorage("reviewIntervalsData") private var reviewIntervalsData: String = "[3,7,30]"
    /// JSON 编码的历史记录数组
    @AppStorage("historyEntriesData") private var historyEntriesData: String = ""
    
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
    
    enum ResultType {
        case success
        case warning
        case error
    }
    
    init() {
        authorizationStatus = calendarManager.checkAuthorizationStatus()
        updateReviewDates()
        
        notificationToken = NotificationCenter.default.addObserver(
            forName: .createReviewSchedule,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.createReviewSchedule()
            }
        }
        
        // 启动时请求权限并加载今天日程
        Task { [weak self] in
            guard let self = self else { return }
            if self.authorizationStatus == .notDetermined {
                let granted = await self.calendarManager.requestAccess()
                self.authorizationStatus = self.calendarManager.checkAuthorizationStatus()
                if granted {
                    self.loadTodayEvents()
                }
            } else if self.authorizationStatus == .fullAccess {
                self.loadTodayEvents()
            }
        }
    }
    
    @MainActor
    deinit {
        if let token = notificationToken {
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
            let (created, duplicates, failed) = try await calendarManager.createReviewEvents(
                title: trimmedTitle,
                baseDate: baseDate,
                intervals: reviewIntervals
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
                
                // 刷新今天日程
                loadTodayEvents()
            }
        } catch {
            resultMessage = error.localizedDescription
            resultType = .error
        }
    }
    
    /// 撤销最近一次创建的复习日程
    func undoReviewSchedule() async {
        let (success, deletedCount, alreadyDeletedCount) = await calendarManager.undoLastCreation()
        
        if success {
            resultMessage = String(format: NSLocalizedString("undo_success", comment: ""), "\(deletedCount)")
            resultType = .success
        } else {
            resultMessage = String(format: NSLocalizedString("undo_partial", comment: ""), "\(alreadyDeletedCount)")
            resultType = .warning
        }
        
        canUndo = false
        loadTodayEvents()
    }
    
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Today Events
    
    func loadTodayEvents() {
        todayEvents = calendarManager.fetchTodayEvents()
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
    
    // MARK: - Theme
    
    func setTheme(_ theme: Theme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
        UserDefaults.standard.set(theme.rawValue, forKey: "themeName")
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
}
