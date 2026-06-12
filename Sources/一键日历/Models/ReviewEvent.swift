import Foundation

struct ReviewEvent: Identifiable {
    let id = UUID()
    let title: String
    let baseDate: Date
    let reviewDates: [Date]
    let notes: [String]
    
    init(title: String, baseDate: Date) {
        self.title = title
        self.baseDate = baseDate
        
        let calendar = Calendar.current
        self.reviewDates = [
            calendar.date(byAdding: .day, value: 3, to: baseDate)!,
            calendar.date(byAdding: .day, value: 7, to: baseDate)!,
            calendar.date(byAdding: .day, value: 30, to: baseDate)!
        ]
        
        self.notes = [
            "第1次复习",
            "第2次复习",
            "第3次复习"
        ]
    }
}
