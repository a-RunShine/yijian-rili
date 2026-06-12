import Foundation

struct ReviewEvent: Identifiable, Codable {
    let id = UUID()
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let notes: [String]
    
    init(title: String, baseDate: Date, intervals: [Int] = [3, 7, 30]) {
        self.title = title
        self.baseDate = baseDate
        self.reviewDates = ReviewEvent.calculateReviewDates(from: baseDate, intervals: intervals)
        self.notes = intervals.enumerated().map { index, _ in
            "第\(index + 1)次复习"
        }
    }
    
    static func calculateReviewDates(from baseDate: Date, intervals: [Int] = [3, 7, 30]) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        
        for interval in intervals {
            if let date = calendar.date(byAdding: .day, value: interval, to: baseDate) {
                dates.append(date)
            } else {
                // 如果日期计算失败，记录错误并跳过
                print("Warning: Failed to calculate date for interval \(interval) from \(baseDate)")
            }
        }
        
        return dates
    }
}
