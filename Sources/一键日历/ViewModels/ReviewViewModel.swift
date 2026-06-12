import Foundation
import SwiftUI
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
    @Published var showHistory: Bool = false
    @Published var showIntervalSettings: Bool = false
    @Published var currentTheme: Theme = {
        let rawValue = UserDefaults.standard.string(forKey: "themeName") ?? Theme.light.rawValue
        return Theme(rawValue: rawValue) ?? .light
    }()
    
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
                
                // Add to history
                addHistoryEntry(title: trimmedTitle, baseDate: baseDate, reviewDates: created)
                
                // Enable undo
                canUndo = true
                
                // Clear inputs after success
                title = ""
                baseDate = Date()
                updateReviewDates()
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
    }
    
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
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
    
    // MARK: - Interval Settings
    
    func resetIntervalsToDefault() {
        reviewIntervals = [3, 7, 30]
        updateReviewDates()
    }
    
    func validateIntervals(_ intervals: [Int]) -> Bool {
        return intervals.allSatisfy { $0 >= 1 }
    }
    
    // MARK: - Theme
    
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "themeName")
    }
}

extension Notification.Name {
    static let createReviewSchedule = Notification.Name("createReviewSchedule")
}
