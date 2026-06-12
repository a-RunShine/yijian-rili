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
    
    private let calendarManager = CalendarManager.shared
    
    enum ResultType {
        case success
        case warning
        case error
    }
    
    init() {
        authorizationStatus = calendarManager.checkAuthorizationStatus()
        updateReviewDates()
        
        NotificationCenter.default.addObserver(
            forName: .createReviewSchedule,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.createReviewSchedule()
            }
        }
    }
    
    func updateReviewDates() {
        let calendar = Calendar.current
        reviewDates = [
            calendar.date(byAdding: .day, value: 3, to: baseDate)!,
            calendar.date(byAdding: .day, value: 7, to: baseDate)!,
            calendar.date(byAdding: .day, value: 30, to: baseDate)!
        ]
    }
    
    func createReviewSchedule() async {
        guard !title.isEmpty else {
            resultMessage = "请输入标题"
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
                resultMessage = "需要日历权限才能创建日程"
                resultType = .error
                return
            }
        } else if authorizationStatus == .denied {
            resultMessage = "日历权限被拒绝，请在系统设置中开启"
            resultType = .error
            return
        }
        
        do {
            let (created, duplicates, failed) = try await calendarManager.createReviewEvents(
                title: title,
                baseDate: baseDate
            )
            
            if !failed.isEmpty {
                let failedDates = failed.map { $0.0.formattedChinese() }.joined(separator: "、")
                resultMessage = "部分创建失败：\(failedDates)"
                resultType = .error
            } else if !duplicates.isEmpty {
                let dupDates = duplicates.map { $0.formattedChinese() }.joined(separator: "、")
                resultMessage = "创建成功！注意以下日期已有同名日程：\(dupDates)"
                resultType = .warning
            } else {
                let createdDates = created.map { $0.formattedChinese() }.joined(separator: "、")
                resultMessage = "成功创建3个复习日程：\(createdDates)"
                resultType = .success
                
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
    
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
